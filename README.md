# su-PathComponentArray

## 概要
選択したEdgeに沿って、選択したComponentInstanceを等ピッチで複製配置する
SketchUp Ruby Extension です。直線のEdgeをパスとして使い、その上に等間隔で
コンポーネントを並べます。

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
│  ├─ path_sampler.rb                  # Edge から配置点を計算
│  ├─ instance_placer.rb               # 配置点ごとにインスタンスを複製
│  └─ version.rb
└─ packaging/
   └─ README.md
```

`su_path_component_array.rb` が Plugins フォルダ直下に置かれることで SketchUp
起動時に読み込まれ、`SketchupExtension` を登録します。実装本体は同名フォルダ
`su_path_component_array/` 側にあります。**この2つはペアで必要**です。

## インストール / 開発時リンク

### 開発時（シンボリックリンク）
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
2. パスとして使う Edge を1本選択する（両方を同時に選択した状態にする）
3. メニュー **Extensions > su-PathComponentArray > Create Path Component Array**
   を実行する
4. 表示される入力ダイアログで `pitch` などを入力する
5. Edge 上に等ピッチでコンポーネントが複製配置される

> メニューの表示位置について: 本拡張は SketchUp の標準プラグインメニュー
> （`UI.menu("Plugins")`）にメニューを登録します。SketchUp 2025 ではこのメニ
> ューは **「Extensions」** という名前で表示されます。

### 入力項目
| 項目 | 意味 |
|---|---|
| Pitch | 配置間隔。長さとして入力します（例: `500` または `500mm`）。 |
| Start offset | Edge 始点から最初の配置点までの距離。 |
| End offset | Edge 終点側で配置しない距離。 |
| Follow path | `Yes` で Edge 方向に沿ってコンポーネントを回転、`No` で元の向きを維持。 |
| Angle offset (degrees) | 追加の回転角度（度）。Follow path が `No` でも追加回転として使えます。 |
| Group result | `Yes` で生成結果を1つのグループにまとめます。 |

配置範囲は次の条件で計算されます。

```text
start_offset <= (始点からの距離) <= edge_length - end_offset
```

### 単位についての注意
- Pitch / Start offset / End offset は **長さ** として扱います。
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

## v0.1 制限
- 複数 Edge / Polyline / Curve は未対応（単一 Edge のみ）
- ランダムピッチは未対応
- 角度の段階変化（配置ごとに角度を変える）は未対応
- 生成後の再編集（パラメータを後から変更）は未対応
- 任意 3D 方向の姿勢制御は未対応または限定対応
- 配置基準は原点固定（中心合わせ・端部合わせ・任意基準点指定は未対応）

> v0.1 では、角度追従は主に XY 平面上の Edge を想定しています。
> 任意 3D 方向の Edge に対する完全な姿勢制御は今後の拡張予定です。

## 今後の拡張予定
- 複数 Edge / Polyline 対応
- Curve 対応
- ランダムピッチ
- ランダム seed
- 角度の段階変化
- HTML Dialog ベースの UI
- プリセット保存
- 生成結果の再編集

## ライセンス / 作者
- Author: airesearchagl-art
- Version: 0.1.0
