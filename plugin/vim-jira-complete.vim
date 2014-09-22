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
if !exists("b:jiracomplete_auth")
  let b:jiracomplete_auth=''
endif

python << EOF
import vim
import json
import requests
import base64

def jira_complete():
    url = vim.eval("g:jiracomplete_url")
    user = vim.eval("g:jiracomplete_username")
    auth = vim.eval("b:jiracomplete_auth")
    query = "jql=assignee=%s+and+resolution=unresolved" % user
    api_url = "%s/rest/api/2/search?%s" % (url, query)
    headers = {}
    if auth:
        headers['authorization'] = 'Basic ' + auth
    response = requests.get(api_url, headers=headers)
    if response.status_code == requests.codes.ok:
        jvalue = json.loads(response.content)
        issues = jvalue['issues']
        match = []
        for issue in issues:
            match.append("{'word': '%s ', 'menu': '%s'}" %
                (issue['key'], issue['fields']['summary']))
        command = "call complete(col('.'), [" + ','.join(match) + "])"
        vim.command(command)
    elif (response.status_code == requests.codes.unauthorized or
            response.status_code == requests.codes.bad_request or
            response.status_code == requests.codes.forbidden):
        vim.command("echohl ErrorMsg")
        vim.command("call inputsave()")
        message = response.reason + "! Please input jira password for " + user
        vim.command("let password = input('"+message+": ')")
        vim.command('call inputrestore()')
        vim.command("echohl None")
        pw = vim.eval('password')
        auth = base64.b64encode(user+':'+pw)
        vim.command("let b:jiracomplete_auth = '"+auth+"'")
        jira_complete()
    else:
        vim.command("return \" Error: " + response.reason + "\"")
EOF
py jira_complete()
return ''
endfunction
