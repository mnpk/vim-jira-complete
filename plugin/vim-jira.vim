if !has('python')
  echo "Error: Required vim compiled with +python"
  finish
endif

inoremap <F5> <C-R>=Jira()<CR>

function! Jira()
if !exists("g:jira_url")
  return "Error: g:jira_url not exists"
endif
if !exists("g:jira_username")
  return "Error: g:jira_username not exists"
endif
python << EOF
import vim
from jira.client import JIRA

url = vim.eval("g:jira_url") 
user = vim.eval("g:jira_username")
jira = JIRA(url)
list = []
for issue in jira.search_issues('assignee='+user+' AND resolution=unresolved'):
  # vim.current.buffer.append("* %s %s" % (issue.key, issue.fields.summary))
  list.append("'<%s %s>'" % (issue.key, issue.fields.summary))

command = "call complete(col('.'), [" + ','.join(list) + "])"
vim.command(command)
EOF
return ''
endfunction
