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
if !exists("g:jiracomplete_password")
  let g:jiracomplete_password=''
endif

python << EOF
import vim
import json
import requests
import base64

def get_password_for(user):
    vim.command("echohl ErrorMsg")
    vim.command("call inputsave()")
    message = "Please input jira password for " + user
    vim.command("let password = inputsecret('"+message+": ')")
    vim.command('call inputrestore()')
    vim.command("echohl None")
    return vim.eval('password')

def jira_complete(need_retry=True):
    url = vim.eval("g:jiracomplete_url")
    user = vim.eval("g:jiracomplete_username")
    pw = vim.eval("g:jiracomplete_password")
    query = "jql=assignee=%s+and+resolution=unresolved" % user
    api_url = "%s/rest/api/2/search?%s" % (url, query)
    headers = {}
    if pw:
        auth = base64.b64encode(user+':'+pw)
        headers['authorization'] = 'Basic ' + auth
    response = requests.get(api_url, headers=headers)
    if response.status_code == requests.codes.ok:
        jvalue = json.loads(response.content)
        issues = jvalue['issues']
        match = []
        for issue in issues:
            match.append("{\"word\": \"%s\", \"menu\": \"%s\"}" %
                (issue['key'], issue['fields']['summary'].replace("\"", "\\\"")))
        command = "call complete(col('.'), [" + ','.join(match) + "])"
        vim.command(command)
    elif (response.status_code == requests.codes.unauthorized or
            response.status_code == requests.codes.bad_request or
            response.status_code == requests.codes.forbidden):
        if need_retry:
            pw = get_password_for(user)
            vim.command("let g:jiracomplete_password = '"+pw+"'")
            jira_complete(need_retry=False)
        else:
            vim.command("return \"Error: " + response.reason + "\"")
    else:
        vim.command("return \"Error: " + response.reason + "\"")
EOF
py jira_complete()
return ''
endfunction
