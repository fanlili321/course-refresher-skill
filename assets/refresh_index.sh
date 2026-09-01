#!/bin/bash
# 重建内容素材库目录索引（类 → 主题 → 知识节点）
# 用法: ./refresh_index.sh [输出路径]  默认写回同目录 kb_index.json
set -e
SPACE=7656740046485064660
OUT="${1:-$(dirname "$0")/kb_index.json"}
TMP=$(mktemp -d)

list(){ lark-cli wiki +node-list --space-id $SPACE --parent-node-token "$1" --as user 2>/dev/null | sed -n '/^{/,$p'; }

# L1: 七大类（根节点）
lark-cli wiki +node-list --space-id $SPACE --as user 2>/dev/null | sed -n '/^{/,$p' > "$TMP/l1.json"

python3 - "$TMP" <<'PY'
import json,sys,os
tmp=sys.argv[1]
n=json.load(open(f'{tmp}/l1.json'))['data']['nodes']
cats=[x for x in n if len(x['title'])>1 and x['title'][0] in 'ABCDEFG' and x['title'][1]==' ']
open(f'{tmp}/l1.txt','w').write('\n'.join(f"{x['node_token']} {x['title']}" for x in cats))
PY

# L2: 主题
: > "$TMP/l2.txt"
while read -r tok rest; do
  list "$tok" | python3 -c "
import sys,json
for x in json.load(sys.stdin)['data']['nodes']: print(x['node_token'],x['title'])
" >> "$TMP/l2.txt"
done < "$TMP/l1.txt"

# L3: 知识节点（并发 12）
mkdir -p "$TMP/l3"; i=0
while read -r tok rest; do
  ( list "$tok" > "$TMP/l3/$tok.json" ) &
  i=$((i+1)); [ $((i % 12)) -eq 0 ] && wait
done < "$TMP/l2.txt"
wait

python3 - "$TMP" "$OUT" "$SPACE" <<'PY'
import json,sys,os,datetime
tmp,out,space=sys.argv[1],sys.argv[2],sys.argv[3]
topics={}
for line in open(f'{tmp}/l2.txt'):
    tok,title=line.split(' ',1); topics[tok]=title.strip()
idx={}; tot=0; miss=[]
for tok,title in topics.items():
    f=f'{tmp}/l3/{tok}.json'
    if not os.path.exists(f) or os.path.getsize(f)==0: miss.append(title); continue
    nodes=json.load(open(f))['data']['nodes']
    idx.setdefault(title,[]).extend({'t':n['node_token'],'n':n['title']} for n in nodes)
    tot+=len(nodes)
meta={'space_id':space,'built_at':datetime.date.today().isoformat(),
      'topics':len(idx),'nodes':tot,'topic_tokens':{v:k for k,v in topics.items()}}
json.dump({'_meta':meta,'topics':idx},open(out,'w'),ensure_ascii=False,indent=0)
print(f'topics={len(idx)} nodes={tot} -> {out}')
if miss: print('MISSING (重跑一次):', miss)
PY
rm -rf "$TMP"
