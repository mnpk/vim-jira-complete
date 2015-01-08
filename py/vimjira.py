# File:       py/vimjira.py                                             {{{1
# Authors:
#   mnpk <https://github.com/mnpk>, initial author of the plugin, 2014
#   Luc Hermitte, enhancements to the plugin, 2014
# Version:      0.2.0
# Description:
#       Internals and API functions for vim-jira-complete
# }}}1
#======================================================================
import vim
import json
import requests
import base64

def get_password_for(user):
    return vim.eval('jira#_get_password("'+user+'")')

def jira_complete(url, user, pw, need_retry=True):
    # print "URL: ", url
    # print "user: ", user
    # print "pw: ", pw
    headers = {}
    if pw:
        auth = base64.b64encode(user+':'+pw)
        headers['authorization'] = 'Basic ' + auth
    query = "jql=assignee=%s+and+resolution=unresolved" % user
    if type(url) == type(dict()):
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

    print "api_url: ", api_url
    print "headers: ", headers
    if response.status_code == requests.codes.ok:
        jvalue = json.loads(response.content)
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
            jira_complete(url, user, pw, need_retry=False)
        else:
            return "Error: " + response.reason
    else:
        return "Error: " + response.reason

