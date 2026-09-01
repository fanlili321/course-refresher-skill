# 批量改写与「修订模式」呈现

## 前提

用户已逐条确认更新清单。**未确认的行不动**。原文档全程只读。

## 一、新建文档（不动原稿）

```bash
# 复制原稿 → 新文档，命名【修订痕迹】原标题
lark-cli drive files copy --file-token <原文档token> --as user \
  --data '{"name":"【修订痕迹】原标题","type":"docx","folder_token":"<目标文件夹token>"}'
```

复制出来的第一版内容 = 原文，**先不要改，让它成为一个干净的基线版本**。
之后每一轮修改，飞书「文档 → 更多 → 历史版本」都能和这个基线逐版对比，这是最接近原生 track changes 的能力。

> 原稿在 wiki 里时，`drive files copy` 用它的 `obj_token`（`wiki +node-get` 可查）。
> 需要放回知识库某个位置，用 `wiki +move` 或 `wiki +node-copy`。

## 二、「修订模式」的三种做法

飞书 OpenAPI **没有**写入原生「建议模式 / track changes」的接口 —— 建议模式只能在网页端人工开。
所以用下面三层组合达到等效效果，默认三层都做：

### 1. 修订痕迹渲染（最直观）

改动处保留旧文并加删除线，新文用颜色标出：

```xml
<p>螺丝钉估值表，到目前为止已经更新了<del><span text-color="gray">2000</span></del><span text-color="red">2950</span>多期了。</p>
```

- 旧文：`<del>` + `text-color="gray"`
- 新文：`text-color="red"`
- 整段重写时，旧段整段 `<del>` 保留在上方，新段跟在下方，中间不留空行。
- 全文颜色语义保持一致，不要另作装饰性着色。

### 2. 锚定批注（说明改动理由和依据）

每处改动在对应句子上挂一条批注，写清「改了什么 + 依据哪张卡 + 置信度」：

```bash
lark-cli drive +add-comment --doc <新文档URL> --type docx --as user \
  --selection-with-ellipsis "螺丝钉估值表...2000多期" \
  --content '[[{"type":"text_run","text_run":{"text":"【维度1 时点数据】2000多期 → 2950多期。依据 B2-221「版本演变」：第2952期（2026-08-12）。置信度：高"}}]]'
```

批注让用户可以逐条「已解决」，等于一份可勾销的复核清单。

### 3. 文末变更汇总表

新文档末尾追加一张表：`序号 | 章节 | 原文 | 新文 | 维度 | 依据卡片 | 置信度`。
方便一屏看完所有改动，也留档给下一次更新。

## 三、执行改写

- 行内换词优先 `str_replace`（保留富文本格式）：

```bash
lark-cli docs +update --doc <新文档> --command str_replace --as user \
  --pattern "已经更新了2000多期" --content "已经更新了2950多期"
```

- `--pattern` 必须在全文**唯一**。不唯一就带上下文加长，或改用 `block_replace --block-id`。
- 整段重写、要加删除线痕迹、要改结构 → `block_replace`，`--doc-format xml`，写入前读 `lark-doc-xml.md`。
- **同一个 block 的多处改动合并成一次 `block_replace`**；每次写操作后旧 block ID 可能失效，下一轮要重新 fetch 取 ID。
- **保护资源块**：`<img>`、`<cite>`、`<sheet>`、`<bitable>`、`<synced_reference>` 原样保留，不能替换成纯文本或占位符。改含图段落时，把原 `<img>` 标签整个抄回新内容里。

## 四、回读校验（必做）

每轮写完重新 fetch 受影响范围，逐项确认：
- 每条已采纳的改动都真的落地了（搜新文关键词）
- 没有误伤相邻段落（对比改前快照）
- 图片、cite、表格都还在，数量与改前一致
- `updated_blocks_count` 和 `warnings` 都检查，`result=success` 也要看 warnings

## 五、交付报告

```
已改 N 条（按维度分组列出）
跳过 M 条：<逐条写原因，如用户未采纳 / pattern 不唯一 / 需人工核实>
待人工换图 K 张：<图注 + 建议新时点 + 出图人>
需人工核实 J 条：<原文 + 疑点 + 为什么库里没依据>
新文档链接 + 基线版本说明（可在历史版本里对比）
```

跳过和待办**必须逐条写清楚**，不能只报成功数。
