if !has('python')
  echo "Error: Required vim compiled with +python"
  finish
endif


inoremap <F5> <C-R>=Jira()<CR>

function! Jira()
if !exists("g:jiracomplete_url")
  return "Error: g:jiracomplete_url not exists"
endif
if !exists("g:jiracomplete_username")
  return "Error: g:jiracomplete_username not exists"
endif
python << EOF
import vim
import json
import requests
url = vim.eval("g:jira_url") 
user = vim.eval("g:jira_username")
query = "jql=assignee=%s+and+resolution=unresolved" % user
api_url = "%s/rest/api/2/search?%s" % (url, query)
issues = json.loads(requests.get(api_url).content)['issues']
match = []
for issue in issues:
  match.append("'%s [%s] '" % (issue['key'], issue['fields']['summary']))
command = "call complete(col('.'), [" + ','.join(match) + "])"
vim.command(command)
EOF
return ''
endfunction
