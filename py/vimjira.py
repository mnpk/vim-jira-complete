# File:       py/vimjira.py                                             {{{1
# Authors:
#   mnpk <https://github.com/mnpk>, initial author of the plugin, 2014
#   Luc Hermitte, enhancements to the plugin, 2014
# Version:      0.2.0
# Description:
#       Internals and API functions for vim-jira-complete
# }}}1
# ======================================================================
import json
import base64
import vim
import requests


def get_password_for(user):
    return vim.eval('jira#_get_password("'+user+'")')


def jira_complete(url, user, pw, need_retry=True, jql="assignee=${user}+and+resolution=unresolved"):
    headers = {}
    if pw:
        auth = base64.b64encode((user+':'+pw).encode())
        headers['authorization'] = 'Basic ' + auth.decode()
    query = "jql=%s" % jql.replace("${user}", user)
    if isinstance(url, dict):
        raw_url = url['url']
        api_url = "%s/rest/api/2/search?%s" % (raw_url, query)
        args = url.copy()
        args.pop('url')
        for k in args.keys():
            if args[k] == 'False' or args[k] == 'True':
                args[k] = eval(args[k])
        response = requests.get(api_url, headers=headers, **args)
    else:
        api_url = "%s/rest/api/2/search?%s" % (url, query)
        response = requests.get(api_url, headers=headers)

    if response.status_code == requests.codes.ok:
        jvalue = json.loads(response.content.decode())
        issues = jvalue['issues']
        match = []
        for issue in issues:
            match.append("{\"abbr\": \"%s\", \"menu\": \"%s\"}" %
                         (issue['key'], issue['fields']['summary'].replace("\"", "\\\"")))
        return ','.join(match)
    elif (response.status_code == requests.codes.unauthorized or
          response.status_code == requests.codes.bad_request or
          response.status_code == requests.codes.forbidden):
        if need_retry:
            pw = get_password_for(user)
            return jira_complete(url, user, pw, need_retry=False, jql=jql)
        elif response.status_code == requests.codes.bad_request:
            jvalue = json.loads(response.content.decode())
            error_messages = jvalue['errorMessages']
            match = []
            for error in error_messages:
                match.append(error)
            return '"%s: %s"' % (response.reason, ','.join(match))
        else:
            return '"Error: %s"' % response.reason
    else:
        return '"Error: %s"' % response.reason
