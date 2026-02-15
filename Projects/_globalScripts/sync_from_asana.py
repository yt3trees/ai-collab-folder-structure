import asana
import json
import os
import re
from datetime import datetime

# --- 環境固有の設定 ---
# デフォルトの出力先ファイルパス
DEFAULT_OUTPUT_FILE = os.path.join(os.path.expanduser('~'), 'Box', 'Obsidian-Vault', 'asana-tasks-view.md')
# 設定ファイルのパス
CONFIG_PATH = 'config.json'
# ----------------------

# 環境変数からトークン取得推奨 (config.jsonは予備)
def load_config():
    if os.path.exists(CONFIG_PATH):
        with open(CONFIG_PATH, 'r', encoding='utf-8') as f:
            return json.load(f)
    return {}

def get_custom_field_value(task, field_name):
    """カスタムフィールドの値を取得する"""
    custom_fields = task.get('custom_fields', [])
    if not custom_fields:
        return None

    for field in custom_fields:
        if field.get('name') == field_name:
            # テキストタイプ
            if field.get('text_value'):
                return field['text_value']
            # 列挙タイプ
            if field.get('enum_value'):
                return field['enum_value'].get('name')
            # 数値タイプ
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
            # メモ領域の開始マーカーを検出
            match = re.search(r'<!-- Memo area for (\w+) -->', line)
            if match:
                # 前のGIDのメモを保存
                if current_gid:
                    memos[current_gid] = "".join(current_memo)

                current_gid = match.group(1)
                current_memo = []
            elif current_gid:
                # 次のタスク開始（- [ ] または - [x]）が来たらメモ終了とみなす
                if re.match(r'^\s*- \[[ x]\]', line):
                    memos[current_gid] = "".join(current_memo)
                    current_gid = None
                    current_memo = []
                else:
                    # メモ内容として蓄積
                    current_memo.append(line)

    # 最後のメモを保存
    if current_gid:
        memos[current_gid] = "".join(current_memo)

    return memos

def sync_from_asana(config):
    """AsanaタスクをMarkdown形式で出力 (View専用) - メモ維持機能付き"""
    token = os.environ.get('ASANA_TOKEN', config.get('asana_token'))
    if not token:
        raise ValueError("ASANA_TOKEN environment variable or config.json with 'asana_token' is required")

    # 新しいAsana SDK (v3+) に対応
    configuration = asana.Configuration()
    configuration.access_token = token
    api_client = asana.ApiClient(configuration)

    # ワークスペースGIDを取得（指定されていない場合は自動取得）
    workspace_gid = os.environ.get('ASANA_WORKSPACE_GID', config.get('workspace_gid'))
    if not workspace_gid:
        print("Workspace GID not specified. Fetching available workspaces...")
        workspaces_api = asana.WorkspacesApi(api_client)
        try:
            workspaces = list(workspaces_api.get_workspaces({}))
            if not workspaces:
                raise ValueError("No workspaces found for this account")
            workspace_gid = workspaces[0]['gid']
            print(f"Using workspace: {workspaces[0]['name']} (GID: {workspace_gid})")
        except Exception as e:
            raise ValueError(f"Failed to fetch workspaces: {e}")

    tasks_api = asana.TasksApi(api_client)

    print("Fetching tasks assigned to me from Asana...")
    tasks = list(tasks_api.get_tasks({
        'assignee': 'me',
        'workspace': workspace_gid,
        'opt_fields': 'name,completed,due_on,assignee,notes,gid,projects,custom_fields,custom_fields.name,custom_fields.text_value,custom_fields.enum_value,custom_fields.number_value',
        'completed_since': 'now'
    }))

    # 出力先ファイルパスを取得（環境変数 > config.json > デフォルト）
    output_file = os.environ.get('ASANA_OUTPUT_FILE', config.get('output_file', DEFAULT_OUTPUT_FILE))

    # 出力先ディレクトリが存在しない場合は作成
    output_dir = os.path.dirname(output_file)
    if output_dir and not os.path.exists(output_dir):
        os.makedirs(output_dir, exist_ok=True)
        print(f"Created output directory: {output_dir}")

    # 既存のメモを読み込む
    existing_memos = load_existing_memos(output_file)

    # 案件ごとにタスクをグループ化
    anken_groups = {}
    for task in tasks:
        anken = get_custom_field_value(task, '案件')
        if not anken:
            anken = '(未分類)'
        if anken not in anken_groups:
            anken_groups[anken] = {'in_progress': [], 'completed': []}

        if task.get('completed'):
            anken_groups[anken]['completed'].append(task)
        else:
            anken_groups[anken]['in_progress'].append(task)

    # 案件をソート（未分類は最後）
    sorted_ankens = sorted([a for a in anken_groups.keys() if a != '(未分類)'])
    if '(未分類)' in anken_groups:
        sorted_ankens.append('(未分類)')

    with open(output_file, 'w', encoding='utf-8') as f:
        f.write(f"# Asana Tasks View (My Tasks)\n")
        f.write(f"Last Sync: {datetime.now().strftime('%Y-%m-%d %H:%M:%S')}\n")
        f.write(f"⚠️ このファイルは自動生成されますが、'Memo area' 以下の記述は保持されます。\n\n")

        # 目次（案件一覧）
        f.write("## 目次\n\n")
        for anken in sorted_ankens:
            in_progress_count = len(anken_groups[anken]['in_progress'])
            completed_count = len(anken_groups[anken]['completed'])
            f.write(f"- [案件: {anken}](#案件-{anken.replace(' ', '-').replace('(', '').replace(')', '')}) (進行中: {in_progress_count}, 完了: {completed_count})\n")
        f.write("\n---\n\n")

        # 案件ごとにセクション出力
        for anken in sorted_ankens:
            f.write(f"## 案件: {anken}\n\n")

            # 進行中のタスク
            f.write("### 進行中のタスク\n\n")
            in_progress_tasks = anken_groups[anken]['in_progress']
            if in_progress_tasks:
                for task in in_progress_tasks:
                    gid = task['gid']
                    due = f" (Due: {task.get('due_on')})" if task.get('due_on') else ""

                    # プロジェクト情報を追加
                    project_info = ""
                    if task.get('projects') and len(task['projects']) > 0:
                        project_names = [p.get('name', '') for p in task['projects'] if p.get('name')]
                        if project_names:
                            project_info = f" [{', '.join(project_names)}]"

                    f.write(f"- [ ] {task['name']}{due}{project_info} [[AsanaLink](https://app.asana.com/0/0/{gid})]\n")

                    # メモエリア開始マーカー
                    f.write(f"    - <!-- Memo area for {gid} -->\n")

                    # 既存メモがあれば書き戻す、なければ空行
                    if gid in existing_memos and existing_memos[gid].strip():
                        f.write(existing_memos[gid])
                    else:
                        f.write("\n")
            else:
                f.write("(タスクなし)\n\n")

            # 完了タスク
            f.write("### 完了タスク (直近)\n\n")
            completed_tasks = anken_groups[anken]['completed']
            if completed_tasks:
                for task in completed_tasks:
                    f.write(f"- [x] {task['name']}\n")
            else:
                f.write("(タスクなし)\n")

            f.write("\n")

    print(f"Exported to: {os.path.abspath(output_file)} (Memos preserved)")

if __name__ == '__main__':
    config = load_config()
    sync_from_asana(config)
