import asana
import json
import os
import re
from datetime import datetime
from pathlib import Path

# --- 環境固有の設定 ---
SCRIPT_DIR = os.path.dirname(os.path.abspath(__file__))
PROJECTS_ROOT = os.path.dirname(SCRIPT_DIR)  # Documents/Projects/
CONFIG_PATH = os.path.join(SCRIPT_DIR, 'config.json')
PATHS_JSON = os.path.join(PROJECTS_ROOT, '_config', 'paths.json')
# ----------------------


def load_config():
    """グローバル設定 (config.json) を読み込む"""
    if os.path.exists(CONFIG_PATH):
        with open(CONFIG_PATH, 'r', encoding='utf-8') as f:
            return json.load(f)
    return {}


def load_paths():
    """paths.json を読み込み、環境変数を展開して返す"""
    if not os.path.exists(PATHS_JSON):
        raise FileNotFoundError(
            f"paths.json not found: {PATHS_JSON}\n"
            "Please create _config/paths.json with localProjectsRoot, boxProjectsRoot, obsidianVaultRoot"
        )
    with open(PATHS_JSON, 'r', encoding='utf-8') as f:
        paths = json.load(f)
    # 環境変数展開
    for key in paths:
        paths[key] = os.path.expandvars(paths[key])
    return paths


def discover_projects(box_projects_root):
    """boxProjectsRoot 配下を走査し、asana_config.json を持つ案件を検出する

    Returns:
        list of dict: [{
            'name': 案件名,
            'box_path': Box側フルパス,
            'relative_path': Projects/ からの相対パス (例: 'Projects/ProjA'),
            'asana_config': asana_config.json の内容
        }, ...]
    """
    projects = []
    # 走査対象パターン: 直下, _mini/, _domains/, _domains/_mini/
    scan_dirs = [
        (box_projects_root, 'Projects'),
        (os.path.join(box_projects_root, '_mini'), 'Projects/_mini'),
        (os.path.join(box_projects_root, '_domains'), 'Projects/_domains'),
        (os.path.join(box_projects_root, '_domains', '_mini'), 'Projects/_domains/_mini'),
    ]

    for scan_dir, prefix in scan_dirs:
        if not os.path.isdir(scan_dir):
            continue
        for entry in os.scandir(scan_dir):
            if not entry.is_dir() or entry.name.startswith('_'):
                continue
            config_file = os.path.join(entry.path, 'asana_config.json')
            if os.path.exists(config_file):
                with open(config_file, 'r', encoding='utf-8') as f:
                    asana_config = json.load(f)
                projects.append({
                    'name': entry.name,
                    'box_path': entry.path,
                    'relative_path': f"{prefix}/{entry.name}",
                    'asana_config': asana_config,
                })
                print(f"  Found: {prefix}/{entry.name} ({len(asana_config.get('asana_project_gids', []))} Asana projects)")

    return projects


def get_custom_field_value(task, field_name):
    """カスタムフィールドの値を取得する"""
    custom_fields = task.get('custom_fields', [])
    if not custom_fields:
        return None

    for field in custom_fields:
        if field.get('name') == field_name:
            if field.get('text_value'):
                return field['text_value']
            if field.get('enum_value'):
                return field['enum_value'].get('name')
            if field.get('number_value') is not None:
                return str(field['number_value'])
    return None


def load_existing_memos(file_path):
    """既存のMarkdownファイルからメモ部分を抽出する"""
    if not os.path.exists(file_path):
        return {}

    memos = {}
    current_gid = None
    current_memo = []

    with open(file_path, 'r', encoding='utf-8') as f:
        for line in f:
            match = re.search(r'<!-- Memo area for (\w+) -->', line)
            if match:
                if current_gid:
                    memos[current_gid] = "".join(current_memo)
                current_gid = match.group(1)
                current_memo = []
            elif current_gid:
                if re.match(r'^\s*- \[[ x]\]', line):
                    memos[current_gid] = "".join(current_memo)
                    current_gid = None
                    current_memo = []
                else:
                    current_memo.append(line)

    if current_gid:
        memos[current_gid] = "".join(current_memo)

    return memos


def classify_task_role(task, user_gid):
    """タスクの自分の役割を判定する

    Returns:
        str: '担当' | 'コラボ' | '他'
    """
    assignee = task.get('assignee')
    if assignee and assignee.get('gid') == user_gid:
        return '担当'

    followers = task.get('followers', [])
    for follower in followers:
        if follower.get('gid') == user_gid:
            return 'コラボ'

    return '他'


def fetch_tasks_for_project(tasks_api, project_gid):
    """Asana プロジェクトから全タスクを取得する"""
    try:
        tasks = list(tasks_api.get_tasks({
            'project': project_gid,
            'opt_fields': (
                'name,completed,due_on,assignee,assignee.name,assignee.gid,'
                'notes,gid,projects,projects.name,'
                'followers,followers.gid,followers.name,'
                'custom_fields,custom_fields.name,'
                'custom_fields.text_value,custom_fields.enum_value,custom_fields.number_value'
            ),
            'completed_since': 'now'
        }))
        return tasks
    except Exception as e:
        print(f"  WARNING: Failed to fetch tasks for project {project_gid}: {e}")
        return []


def fetch_project_name(projects_api, project_gid):
    """Asana プロジェクト名を取得する"""
    try:
        project = projects_api.get_project(project_gid, {'opt_fields': 'name'})
        return project.get('name', project_gid)
    except Exception as e:
        print(f"  WARNING: Failed to fetch project name for {project_gid}: {e}")
        return project_gid


def write_task_line(f, task, role, existing_memos):
    """タスクの1行を出力する"""
    gid = task['gid']
    checkbox = 'x' if task.get('completed') else ' '
    due = f" (Due: {task.get('due_on')})" if task.get('due_on') else ""
    role_tag = f"[{role}] " if role else ""

    f.write(f"- [{checkbox}] {role_tag}{task['name']}{due} [[Asana](https://app.asana.com/0/0/{gid})]\n")

    if not task.get('completed'):
        f.write(f"    - <!-- Memo area for {gid} -->\n")
        if gid in existing_memos and existing_memos[gid].strip():
            f.write(existing_memos[gid])
        else:
            f.write("\n")


def write_project_section(f, project_name, tasks, user_gid, existing_memos):
    """Asana プロジェクト単位のセクションを出力する"""
    f.write(f"## {project_name}\n\n")

    in_progress = [t for t in tasks if not t.get('completed')]
    completed = [t for t in tasks if t.get('completed')]

    # 進行中タスク
    f.write("### 進行中\n\n")
    if in_progress:
        # 担当 → コラボ → 他 の順にソート
        role_order = {'担当': 0, 'コラボ': 1, '他': 2}
        for task in sorted(in_progress, key=lambda t: role_order.get(classify_task_role(t, user_gid), 9)):
            role = classify_task_role(task, user_gid)
            write_task_line(f, task, role, existing_memos)
    else:
        f.write("(タスクなし)\n\n")

    # 完了タスク
    f.write("### 完了 (直近)\n\n")
    if completed:
        for task in completed:
            role = classify_task_role(task, user_gid)
            write_task_line(f, task, role, existing_memos)
    else:
        f.write("(タスクなし)\n")

    f.write("\n")


def write_project_file(output_path, project_name, sections, personal_tasks, user_gid):
    """案件別の asana-tasks.md を出力する

    Args:
        output_path: 出力先ファイルパス
        project_name: 案件名
        sections: [(asana_project_name, [tasks]), ...] Asana プロジェクトごとのタスク
        personal_tasks: 個人プロジェクトから振り分けられたタスク
        user_gid: 自分の Asana ユーザー GID
    """
    existing_memos = load_existing_memos(output_path)

    output_dir = os.path.dirname(output_path)
    if output_dir and not os.path.exists(output_dir):
        os.makedirs(output_dir, exist_ok=True)

    with open(output_path, 'w', encoding='utf-8') as f:
        f.write(f"# Asana Tasks: {project_name}\n")
        f.write(f"Last Sync: {datetime.now().strftime('%Y-%m-%d %H:%M:%S')}\n\n")
        f.write(f"> このファイルは sync_from_asana.py により自動生成されます。\n")
        f.write(f"> 'Memo area' 以下の記述は保持されます。\n\n")

        # Asana プロジェクトごとのセクション
        for asana_project_name, tasks in sections:
            write_project_section(f, asana_project_name, tasks, user_gid, existing_memos)

        # 個人タスクからの振り分け
        if personal_tasks:
            write_project_section(f, "個人タスクより", personal_tasks, user_gid, existing_memos)

    print(f"  Output: {output_path}")


def write_personal_file(output_path, tasks, user_gid):
    """個人/未分類タスクの asana-tasks-personal.md を出力する"""
    existing_memos = load_existing_memos(output_path)

    output_dir = os.path.dirname(output_path)
    if output_dir and not os.path.exists(output_dir):
        os.makedirs(output_dir, exist_ok=True)

    with open(output_path, 'w', encoding='utf-8') as f:
        f.write(f"# Asana Tasks: 個人 / 未分類\n")
        f.write(f"Last Sync: {datetime.now().strftime('%Y-%m-%d %H:%M:%S')}\n\n")
        f.write(f"> このファイルは sync_from_asana.py により自動生成されます。\n")
        f.write(f"> 'Memo area' 以下の記述は保持されます。\n\n")

        in_progress = [t for t in tasks if not t.get('completed')]
        completed = [t for t in tasks if t.get('completed')]

        f.write("## 進行中\n\n")
        if in_progress:
            for task in in_progress:
                role = classify_task_role(task, user_gid)
                write_task_line(f, task, role, existing_memos)
        else:
            f.write("(タスクなし)\n\n")

        f.write("## 完了 (直近)\n\n")
        if completed:
            for task in completed:
                role = classify_task_role(task, user_gid)
                write_task_line(f, task, role, existing_memos)
        else:
            f.write("(タスクなし)\n")

    print(f"  Output: {output_path}")


def write_global_summary(output_path, all_project_data, personal_tasks, user_gid):
    """全案件のグローバルサマリー (asana-tasks-view.md) を出力する

    Args:
        output_path: 出力先ファイルパス
        all_project_data: [(project_name, sections, personal_tasks_for_project), ...]
        personal_tasks: 未分類の個人タスク
        user_gid: 自分の Asana ユーザー GID
    """
    existing_memos = load_existing_memos(output_path)

    output_dir = os.path.dirname(output_path)
    if output_dir and not os.path.exists(output_dir):
        os.makedirs(output_dir, exist_ok=True)

    with open(output_path, 'w', encoding='utf-8') as f:
        f.write(f"# Asana Tasks View (All Projects)\n")
        f.write(f"Last Sync: {datetime.now().strftime('%Y-%m-%d %H:%M:%S')}\n")
        f.write(f"> このファイルは sync_from_asana.py により自動生成されます。\n")
        f.write(f"> 各案件の詳細は個別の asana-tasks.md を参照してください。\n")
        f.write(f"> 'Memo area' 以下の記述は保持されます。\n\n")

        # 目次
        f.write("## 目次\n\n")
        for project_name, sections, proj_personal in all_project_data:
            total_in_progress = sum(
                len([t for t in tasks if not t.get('completed')])
                for _, tasks in sections
            )
            total_in_progress += len([t for t in proj_personal if not t.get('completed')])
            anchor = project_name.replace(' ', '-').replace('(', '').replace(')', '')
            f.write(f"- [{project_name}](#{anchor}) (進行中: {total_in_progress})\n")
        if personal_tasks:
            f.write(f"- [個人 / 未分類](#個人--未分類) (進行中: {len([t for t in personal_tasks if not t.get('completed')])})\n")
        f.write("\n---\n\n")

        # 各案件セクション
        for project_name, sections, proj_personal in all_project_data:
            f.write(f"## {project_name}\n\n")

            all_tasks = []
            for asana_proj_name, tasks in sections:
                all_tasks.extend(tasks)
            all_tasks.extend(proj_personal)

            in_progress = [t for t in all_tasks if not t.get('completed')]
            if in_progress:
                for task in in_progress:
                    role = classify_task_role(task, user_gid)
                    write_task_line(f, task, role, existing_memos)
            else:
                f.write("(タスクなし)\n\n")

            f.write("\n")

        # 個人/未分類
        if personal_tasks:
            f.write("## 個人 / 未分類\n\n")
            in_progress = [t for t in personal_tasks if not t.get('completed')]
            if in_progress:
                for task in in_progress:
                    role = classify_task_role(task, user_gid)
                    write_task_line(f, task, role, existing_memos)
            else:
                f.write("(タスクなし)\n")
            f.write("\n")

    print(f"  Output: {output_path}")


def sync_from_asana():
    """メイン処理: Asana タスクを案件別に Obsidian Vault へ同期"""
    # --- 設定読み込み ---
    config = load_config()
    paths = load_paths()

    token = os.environ.get('ASANA_TOKEN', config.get('asana_token'))
    if not token:
        raise ValueError("ASANA_TOKEN environment variable or config.json with 'asana_token' is required")

    user_gid = os.environ.get('ASANA_USER_GID', config.get('user_gid'))
    if not user_gid:
        raise ValueError("'user_gid' is required in config.json or ASANA_USER_GID env var")

    box_projects_root = paths['boxProjectsRoot']
    obsidian_vault_root = paths['obsidianVaultRoot']
    personal_project_gids = config.get('personal_project_gids', [])
    output_file = os.environ.get('ASANA_OUTPUT_FILE', config.get(
        'output_file',
        os.path.join(obsidian_vault_root, 'asana-tasks-view.md')
    ))

    # --- Asana API クライアント初期化 ---
    configuration = asana.Configuration()
    configuration.access_token = token
    api_client = asana.ApiClient(configuration)
    tasks_api = asana.TasksApi(api_client)
    projects_api = asana.ProjectsApi(api_client)

    # --- 案件検出 ---
    print("[1/5] Discovering projects with asana_config.json...")
    discovered = discover_projects(box_projects_root)
    if not discovered and not personal_project_gids:
        print("No projects with asana_config.json found and no personal projects configured.")
        return

    # --- 案件ごとにタスク取得 ---
    print("\n[2/5] Fetching tasks for each project...")
    all_project_data = []  # [(name, sections, personal_for_this_project)]
    project_name_set = {p['name'] for p in discovered}  # 案件名マッチ用

    for proj in discovered:
        print(f"\n  --- {proj['name']} ---")
        sections = []
        for gid in proj['asana_config'].get('asana_project_gids', []):
            asana_proj_name = fetch_project_name(projects_api, gid)
            print(f"    Fetching: {asana_proj_name} ({gid})")
            tasks = fetch_tasks_for_project(tasks_api, gid)
            print(f"    -> {len(tasks)} tasks")
            sections.append((asana_proj_name, tasks))
        all_project_data.append({
            'project': proj,
            'sections': sections,
            'personal_tasks': [],  # 後で個人プロジェクトから振り分け
        })

    # --- 個人プロジェクトのタスク取得と振り分け ---
    print("\n[3/5] Fetching personal project tasks...")
    unmatched_personal_tasks = []

    for gid in personal_project_gids:
        asana_proj_name = fetch_project_name(projects_api, gid)
        print(f"  Fetching: {asana_proj_name} ({gid})")
        tasks = fetch_tasks_for_project(tasks_api, gid)
        print(f"  -> {len(tasks)} tasks")

        for task in tasks:
            anken = get_custom_field_value(task, '案件')
            matched = False
            if anken:
                for proj_data in all_project_data:
                    if proj_data['project']['name'] == anken:
                        proj_data['personal_tasks'].append(task)
                        matched = True
                        break
            if not matched:
                unmatched_personal_tasks.append(task)

    distributed_count = sum(len(pd['personal_tasks']) for pd in all_project_data)
    print(f"  Distributed {distributed_count} to projects, {len(unmatched_personal_tasks)} unmatched")

    # --- 案件別ファイル出力 ---
    print("\n[4/5] Writing per-project files...")
    summary_data = []

    for proj_data in all_project_data:
        proj = proj_data['project']
        obsidian_path = os.path.join(obsidian_vault_root, proj['relative_path'])
        output_path = os.path.join(obsidian_path, 'asana-tasks.md')

        write_project_file(
            output_path=output_path,
            project_name=proj['name'],
            sections=proj_data['sections'],
            personal_tasks=proj_data['personal_tasks'],
            user_gid=user_gid,
        )
        summary_data.append((proj['name'], proj_data['sections'], proj_data['personal_tasks']))

    # 個人/未分類ファイル
    if unmatched_personal_tasks:
        personal_output = os.path.join(obsidian_vault_root, 'asana-tasks-personal.md')
        write_personal_file(personal_output, unmatched_personal_tasks, user_gid)

    # --- グローバルサマリー出力 ---
    print("\n[5/5] Writing global summary...")
    write_global_summary(output_file, summary_data, unmatched_personal_tasks, user_gid)

    print(f"\nSync complete! ({len(all_project_data)} projects processed)")


if __name__ == '__main__':
    sync_from_asana()
