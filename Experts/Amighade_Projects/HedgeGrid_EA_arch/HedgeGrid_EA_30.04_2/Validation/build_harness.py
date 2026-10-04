from pathlib import Path
import re
p=Path(__file__).resolve().parents[1]
seen=set()
def flatten(f):
 f=f.resolve()
 if f in seen:return ''
 seen.add(f);s=f.read_text()
 s=re.sub(r'^\s*#include "([^"]+)".*$',lambda m:flatten(f.parent/m[1]),s,flags=re.M)
 s=re.sub(r'^\s*#(?:ifndef|define|endif|property).*$', '',s,flags=re.M)
 s=re.sub(r'\binput\s+','',s)
 s=re.sub(r'\b(TradeItem|TransactionItem|double|int|ENUM_ORDER_TYPE)\s+(\w+)\[\]',r'std::vector<\1> \2',s)
 return s
text=flatten(p/'HedgeGrid.mq5')
(p/'Validation'/'ea_under_test.hpp').write_text(text)
print('Translated',len(seen),'active files; only include/input/array syntax adapted for C++ mock runtime.')
