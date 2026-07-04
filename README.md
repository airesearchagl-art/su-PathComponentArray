# su-PathComponentArray

## 概要
選択したEdge（単一Edge、または連続する複数EdgeによるPolyline）に沿って、選択した
ComponentInstanceを等ピッチで複製配置する SketchUp Ruby Extension です。

## 対象環境
- SketchUp 2025
- Windows 想定
- Ruby Extension（SketchUp 同梱の Ruby で動作。外部 gem 不要）

## ディレクトリ構成
SketchUp の Plugins フォルダから安定して読み込めることを優先し、ローダー用の
`.rb` ファイルと実装フォルダをリポジトリ直下に置いています。

```text
su-PathComponentArray/
├─ README.md
├─ .gitignore
├─ su_path_component_array.rb          # ローダー（SketchupExtension を登録）
├─ su_path_component_array/
│  ├─ extension.rb                     # メニュー登録・コマンド本体
│  ├─ path_sampler.rb                  # Edge / Polyline から配置点を計算
│  ├─ instance_placer.rb               # 配置点ごとにインスタンスを複製
│  └─ version.rb
├─ scripts/
│  ├─ setup_local_dev.ps1              # 初回: clone + checkout + symlink 作成
│  ├─ update_local_dev.ps1             # 更新: git pull + ブランチ確認/切替
│  └─ update_local_dev.bat             # 更新をダブルクリックで実行するラッパー
├─ docs/
│  └─ v0.1_development_digest.md       # v0.1 開発ダイジェスト（Vault転記用要約）
└─ packaging/
   └─ README.md
```

`su_path_component_array.rb` が Plugins フォルダ直下に置かれることで SketchUp
起動時に読み込まれ、`SketchupExtension` を登録します。実装本体は同名フォルダ
`su_path_component_array/` 側にあります。**この2つはペアで必要**です。

## インストール / 開発時リンク

Claude Code 側の作業環境と、あなたの Windows ローカル PC の SketchUp Plugins
フォルダは**別環境**です。GitHub に PR や commit を作成しても、ローカル PC の
Plugins フォルダは自動更新されません。そのため、ローカル側で初回セットアップ・
更新を行う PowerShell スクリプトを `scripts/` に同梱しています。**通常はこちらの
スクリプトを使用してください。**

### スクリプトによる自動セットアップ / 更新（推奨）

| スクリプト | 役割 |
|---|---|
| `scripts/setup_local_dev.ps1` | リポジトリの clone → ブランチ checkout → Plugins フォルダへのシンボリックリンク作成（初回） |
| `scripts/update_local_dev.ps1` | clone 済みリポジトリの `git pull` → ブランチ確認 / 切替 → 再起動案内（更新） |
| `scripts/update_local_dev.bat` | 上記更新スクリプトを**ダブルクリック**で実行するラッパー（2回目以降の更新用） |

#### 事前準備
- **Git for Windows** をインストール（`git` が PATH にあること）。
- シンボリックリンク作成には、**管理者権限の PowerShell**（「管理者として実行」）
  または **開発者モード**（設定 > プライバシーとセキュリティ > 開発者向け）が必要です。
- スクリプト実行がブロックされる場合は、次のように実行してください。

  ```powershell
  powershell -ExecutionPolicy Bypass -File .\scripts\setup_local_dev.ps1
  ```

#### 初回セットアップ
リポジトリのルートで実行します。`-RepoPath` には clone 先の固定フォルダを指定して
ください。省略時の既定は次の固定フォルダです。

```text
C:\Users\shuns\.claude\projects\su-PathComponentArray
```

> この既定は、OneDrive 同期対象になりがちな Documents 配下を避け、長期的に動かさ
> ない前提の固定フォルダとして `.claude\projects` 配下を採用しています。SketchUp の
> Plugins フォルダからは、この固定 clone 先へシンボリックリンクを張ります。別の場所
> を使いたい場合は `-RepoPath` で上書きしてください。

```powershell
# 既定値（ブランチ main、Plugins は %APPDATA% から自動解決）で実行
.\scripts\setup_local_dev.ps1

# clone 先・ブランチを明示する例
.\scripts\setup_local_dev.ps1 `
  -RepoPath "D:\dev\su-PathComponentArray" `
  -Branch  "main"
```

このスクリプトは次を行います。

1. `-RepoPath` へリポジトリを clone（既に clone 済みなら再利用）
2. `-Branch`（既定 `main`）を fetch して checkout
3. Plugins フォルダ（既定 `%APPDATA%\SketchUp\SketchUp 2025\SketchUp\Plugins`）へ
   `su_path_component_array.rb` と `su_path_component_array` フォルダのリンクを作成
4. 「SketchUp 2025 を再起動してください」と案内

主なパラメータ:

| パラメータ | 既定値 | 説明 |
|---|---|---|
| `-RepoPath` | `C:\Users\shuns\.claude\projects\su-PathComponentArray` | clone 先（リポジトリルート） |
| `-Branch` | `main` | checkout するブランチ |
| `-RepoUrl` | GitHub リポジトリ URL | clone 元 |
| `-PluginsPath` | `%APPDATA%\SketchUp\SketchUp 2025\SketchUp\Plugins` | SketchUp 2025 Plugins フォルダ |
| `-Force` | （なし） | リンク先に既存の実ファイル/フォルダがある場合に置き換える |

#### 更新
clone 済みリポジトリを最新化します。`-RepoPath` は**初回セットアップと同じ値**を
指定してください。

> **ブランチ方針:** v0.1 MVP の PR #1 は `main` に merge 済みです。**通常運用では
> `main` を追従します**（各スクリプトの `-Branch` 既定は `main`）。特定の作業ブランチを
> 更新したい場合のみ `-Branch` を明示指定してください。

```powershell
# 通常運用: main を追従して更新（-Branch の既定は main）
.\scripts\update_local_dev.ps1

# 別の作業ブランチを更新したい場合のみ明示指定
.\scripts\update_local_dev.ps1 -Branch "feature/xxxx"
```

このスクリプトは次を行います。

1. 現在のブランチを表示
2. `origin` を fetch
3. `-Branch`（既定 `main`）のブランチへ checkout（通常は `main`）
4. `git pull --ff-only` で更新（fast-forward できない場合は警告して中断）
5. 「SketchUp 2025 を再起動してください」と案内

> リンクは作り直しません。リンクはローカル作業コピーを指しているため、`git pull`
> 後に SketchUp を再起動すれば新しいコードが読み込まれます。

> **パスについての注意:** スクリプトは clone 先や Plugins フォルダを既定値・パラメータ
> として明示的に受け取ります。環境に合わせて `-RepoPath` / `-PluginsPath` を指定して
> ください（不明なパスを推測する動作はしません）。

#### 2回目以降のローカル更新（.bat ダブルクリック）
2回目以降の更新は、通常 **`scripts/update_local_dev.bat` をダブルクリック**するだけで
完了します。この `.bat` は clone 済みフォルダ
（`C:\Users\shuns\.claude\projects\su-PathComponentArray`）内に置かれている前提です。

`.bat` は内部で次を実行します。

```bat
.\scripts\update_local_dev.ps1 -Branch "main"
```

実行後の流れ:

1. `git pull` でローカル clone を最新化（ブランチは `main`）
2. 完了メッセージを表示し、`pause` でウィンドウを保持
3. **更新後は SketchUp 2025 を再起動**して最新のプラグインコードを読み込む

> **クラウド実行時の注意:** Claude Code がクラウド側で動いている場合、Windows ローカルの
> Plugins フォルダは**自動更新されません**。その場合は、この `.bat` または
> `update_local_dev.ps1` を**ユーザーがローカルで実行**して反映してください。
> Claude Code CLI などローカル PowerShell を実行できる環境であれば、作業後に
> `update_local_dev.ps1` を実行して反映できる可能性があります。

### 手動でのシンボリックリンク作成（参考）
スクリプトを使わずに手動で設定する場合の手順です。
開発中はリポジトリを編集しながら SketchUp 2025 で読み込めるよう、Plugins
フォルダにシンボリックリンクを作成します。

Plugins フォルダ（Windows）:

```text
C:\Users\shuns\AppData\Roaming\SketchUp\SketchUp 2025\SketchUp\Plugins
```

ローダー `.rb` と実装フォルダの**両方**にリンクを張ります。`<repo-path>` は
実際にこのリポジトリをクローンしたローカルパスに置き換えてください。

ローダー `.rb` ファイルへのリンク:

```powershell
New-Item -ItemType SymbolicLink `
  -Path "C:\Users\shuns\AppData\Roaming\SketchUp\SketchUp 2025\SketchUp\Plugins\su_path_component_array.rb" `
  -Target "<repo-path>\su_path_component_array.rb"
```

実装フォルダへのリンク:

```powershell
New-Item -ItemType SymbolicLink `
  -Path "C:\Users\shuns\AppData\Roaming\SketchUp\SketchUp 2025\SketchUp\Plugins\su_path_component_array" `
  -Target "<repo-path>\su_path_component_array"
```

> シンボリックリンク作成には管理者権限の PowerShell が必要な場合があります。
> リンク作成後、SketchUp を再起動すると拡張が読み込まれます。

### 配布時（参考）
配布用 RBZ の作り方は `packaging/README.md` を参照してください（本リポジトリ
には RBZ などのバイナリは含めません）。

## 使い方
1. 配置元の ComponentInstance を1つ選択する
2. パスとして使う Edge を1本、または連続する複数Edge（Polyline状のEdge列）を
   選択する（ComponentInstance と同時に選択した状態にする）
3. メニュー **Extensions > su-PathComponentArray > Create Path Component Array**
   を実行する
4. 表示される入力ダイアログで「ピッチ」「ピッチ方式」などを入力する
5. パス上に等ピッチでコンポーネントが複製配置される

> **複数Edge選択時の条件（v0.2）:** 選択した複数Edgeは、端点同士が接続した
> **1本の連続したチェーン**である必要があります。分岐している、不連続な
> Edgeが混ざっている、複数の独立したパスが選択されている、閉じたループに
> なっている場合はエラーメッセージを表示して中断します（詳細は後述の
> 「v0.2 制限」を参照）。Edge の選択順序は問いません（内部で端点のつながりから
> 自動的に並べ替えます）。

> メニューの表示位置について: 本拡張は SketchUp の標準プラグインメニュー
> （`UI.menu("Plugins")`）にメニューを登録します。SketchUp 2025 ではこのメニ
> ューは **「Extensions」** という名前で表示されます。

### 入力項目
| 項目 | 意味 |
|---|---|
| ピッチ | 配置間隔。長さとして入力します（例: `500` または `500mm`）。 |
| 開始オフセット | パスの始点から最初の配置点までの距離。 |
| 終了オフセット | パスの終点側で配置しない距離。 |
| パス方向に追従 | `はい` でパス（Edge / Polyline）の方向に沿ってコンポーネントを回転、`いいえ` で元の向きを維持。 |
| 追加角度（度） | 追加の回転角度（度）。「パス方向に追従」が `いいえ` でも追加回転として使えます。 |
| 結果をグループ化 | `はい` で生成結果を1つのグループにまとめます。 |
| ピッチ方式 | `全体累積長` または `Edgeごとリセット` から選択します（複数Edge選択時の配置ロジックを切り替えます。詳細は次項）。単一Edge選択時はどちらを選んでも結果は同じです。 |

### ピッチ方式（複数Edge / Polyline選択時）
複数Edge（Polyline）を選択した場合、ピッチの数え方を次の2種類から選べます。

**全体累積長（既定値）**
選択した複数Edgeを1本の連続したパスとして扱い、パス全体の累積距離に対して
ピッチ間隔で配置します。

```text
start_offset <= (始点からの累積距離) <= total_length - end_offset
```

例: 1m + 1m + 1m の Polyline（全長3000mm）に対して、pitch = 300mm、
start_offset = 0、end_offset = 0 の場合、0mm, 300mm, 600mm, ... , 3000mm の
位置に配置され、**始点と終点を含めて合計11個**になります。この方式では、
曲がり角の直前・直後に配置点が出る場合がありますが、仕様どおりの動作です。

**Edgeごとリセット**
選択した複数Edgeを連続パスとして扱いつつ、ピッチ配置は **Edgeごとにリセット**
します。各Edgeの始点から `start_offset` を適用し、そのEdge内で
`edge_length - end_offset` まで配置したら、次のEdgeでまた0から配置を始めます。

```text
（各Edgeごとに） start_offset <= (そのEdge内の距離) <= edge_length - end_offset
```

例: 1mのEdgeが3本、pitch = 300mmの場合、各Edgeごとに 0mm, 300mm, 600mm, 900mm
の位置に配置されます（3本で合計12個）。ジグザグや折れ線の各辺ごとに均等感を
出したい場合に使う方式です。

> **Edgeごとリセットの注意点:** `start_offset` / `end_offset` は各Edgeに
> 個別に適用されます。そのため、Edgeの長さが `start_offset + end_offset` より
> 短い場合、そのEdgeには配置点が作られません（エラーにはならず、単にその
> Edgeがスキップされます）。また、Edge境界（隣り合うEdgeが接続する頂点）の
> 近くで、前のEdgeの最後の配置点と次のEdgeの最初の配置点がほぼ同じ位置に
> 重なって配置される場合があります。v0.2では重複除去を行わないため、意図的な
> 仕様として扱っています。

単一Edgeを選択した場合、上記どちらの方式を選んでも結果は同じです（Edgeが
1本しかないため、全体累積長とEdgeごとリセットの計算が一致します）。

複数Edgeの場合、「パス方向に追従」が `はい` のときは、どちらの方式でも
**配置点が属する区間（segment）の接線方向**に基づいて回転するため、Polyline
が折れ曲がる箇所ではコンポーネントの向きもそれに応じて変わります。

### 単位についての注意
- ピッチ / 開始オフセット / 終了オフセット は **長さ** として扱います。
- 数値のみ（例 `500`）を入力した場合、**モデルの現在の単位**として解釈されます。
  モデル単位が mm なら `500` は 500mm、インチなら 500 インチになります。
- 単位を明示したい場合は `500mm`、`50cm`、`2'` のように単位付きで入力できます。
- 内部的には SketchUp の内部単位（インチ）に変換して処理します。
- 想定どおりの間隔にならない場合は、まず単位付きで入力して確認してください。

## v0.1 MVP仕様
- 単一 Edge のみ対応
- 等ピッチ配置
- ComponentInstance の**原点**をパス上の配置点に配置
- 角度追従は主に **XY 平面上の Edge 方向**に対する Z 軸回転を想定
- 処理全体を1回の Undo 操作にまとめる
- `Group result = Yes` で生成インスタンスを1つのグループにまとめる

## v0.2 MVP仕様
- 単一 Edge に加え、**端点同士が接続した連続する複数 Edge（Polyline状のEdge列）**
  にも対応
- Edge の選択順序は不問（内部で端点のつながりから自動的に並べ替え）
- **ピッチ方式を「全体累積長」「Edgeごとリセット」から選択可能**（既定値は
  「全体累積長」。詳細は前述の「ピッチ方式（複数Edge / Polyline選択時）」を参照）
- `パス方向に追従 = はい` の角度追従は、**配置点が属する区間（segment）の
  接線方向**に基づいて計算（Polyline が折れ曲がる箇所では、区間ごとに向きが
  変わる）
- 角度追従は v0.1 と同様、主に **XY 平面上の Edge / Polyline 方向**に対する
  Z 軸回転を想定
- 単一Edge選択時の挙動は v0.1 から変更なし
- UI（`UI.inputbox`・選択エラー・完了メッセージ）は日本語表示に変更

## v0.2 制限
- 分岐している Edge の選択は未対応（エラーとして中断）
- 端点が接続していない不連続な Edge の混在は未対応（エラーとして中断）
- 複数の独立したパスの同時選択は未対応（エラーとして中断）
- 閉じたループ（始点・終点が一意に決まらない Edge の輪）は未対応
  （エラーとして中断。今後の拡張予定）
- 「Edgeごとリセット」方式では、Edge境界付近で配置点が重複するように見える
  場合があり、v0.2では重複除去を行いません（意図的な仕様。詳細は前述の
  「ピッチ方式」を参照）
- 「Edgeごとリセット」方式では、`start_offset + end_offset` より短いEdgeには
  配置点が作られません（エラーにはならず、そのEdgeがスキップされます）
- Curve（真の曲線エンティティ）への対応は未対応
- ランダムピッチ・角度の段階変化は未対応
- HTML Dialog 化は未対応
- 生成後の再編集（パラメータを後から変更）は未対応
- 任意 3D 方向の完全な姿勢制御は未対応または限定対応
- 配置基準は原点固定（中心合わせ・端部合わせ・任意基準点指定は未対応）

> v0.2 でも、角度追従は主に XY 平面上の Edge / Polyline を想定しています。
> 任意 3D 方向の Edge / Polyline に対する完全な姿勢制御は今後の拡張予定です。

## v0.2 実機確認状況
SketchUp 2025 / Windows 環境で、以下を確認済みです。

- 単一Edgeでの既存配置（回帰確認）
- 連続する複数Edge / Polylineでの配置
- 選択順に依存しないEdge順序付け
- L字Polylineでのsegment方向追従
- 不連続Edgeのエラー表示
- 分岐Edgeのエラー表示
- 閉じたループのエラー表示
- Undoによる一括取り消し

**追加修正（本PR内で追加、v0.2の実機確認範囲には未反映）:**
- Polylineのピッチ方式を「全体累積長」と「Edgeごとリセット」から選べるように
  した
- `UI.inputbox` / エラーメッセージ / 完了メッセージを日本語中心に改善した

> 上記の「追加修正」2点は、このPR内でのロジック検証（スタブテスト）は
> 済んでいますが、SketchUp実機での動作確認はまだ行われていません。実機確認
> 前の機能として扱ってください。

## v0.1 実機確認状況
SketchUp 2025 / Windows 環境で、以下を確認済みです。

- `setup_local_dev.ps1` による clone / checkout / symlink 作成
  （`su_path_component_array.rb` とフォルダ両方の SymbolicLink 作成を含む）
- SketchUp 2025 での拡張読み込み
- ComponentInstance 1つ + Edge 1本による配列配置（例: 7 components placed）
- Ctrl+Z（Undo）による一括取り消し
- 起動時に継続的なエラーが出ないこと
- `follow_path` / `angle_offset_degrees` の基本動作

## v0.1 制限
（このセクションは v0.1 時点の制限です。複数 Edge / Polyline 対応は v0.2 で
追加されました。最新の制限は上記「v0.2 制限」を参照してください。）
- 複数 Edge / Polyline / Curve は未対応（単一 Edge のみ）
- ランダムピッチは未対応
- 角度の段階変化（配置ごとに角度を変える）は未対応
- 生成後の再編集（パラメータを後から変更）は未対応
- 任意 3D 方向の姿勢制御は未対応または限定対応
- 配置基準は原点固定（中心合わせ・端部合わせ・任意基準点指定は未対応）

> v0.1 では、角度追従は主に XY 平面上の Edge を想定しています。
> 任意 3D 方向の Edge に対する完全な姿勢制御は今後の拡張予定です。

## 今後の拡張予定
- 閉じたループ対応
- 分岐パス対応
- Curve 対応
- ランダムピッチ
- ランダム seed
- 角度の段階変化
- HTML Dialog ベースの UI
- プリセット保存
- 生成結果の再編集
- 任意 3D 方向の完全な姿勢制御

## ライセンス / 作者
- Author: airesearchagl-art
- Version: 0.1.0
