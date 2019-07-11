"=============================================================================
" $Id$
" File:         vim-jira-complete/autoload/jira.vim {{{1
" Authors:
"   mnpk <https://github.com/mnpk>, initial author of the plugin, 2014
"   Luc Hermitte, enhancements to the plugin, 2014
"   jira#lh_... functions are copied from Luc Hermitte's vim library [lh-vim-lib](http://code.google.com/p/lh-vim/wiki/lhVimLib).
"   Bart Libert, enhancements, 2018-2019
" Version:      0.3.0
let s:k_version = 030
"------------------------------------------------------------------------
" Description:
"       Internals and API functions for vim-jira-complete
" }}}1
"=============================================================================

let s:cpo_save=&cpoptions
set cpoptions&vim
"------------------------------------------------------------------------
" ## Misc Functions     {{{1
" # Version {{{2
function! jira#version() abort
  return s:k_version
endfunction

" # Debug   {{{2
if !exists('s:verbose')
  let s:verbose = 0
endif
function! jira#verbose(...) abort
  if a:0 > 0 | let s:verbose = a:1 | endif
  return s:verbose
endfunction

function! s:Verbose(expr) abort
  if s:verbose
    echomsg a:expr
  endif
endfunction

function! jira#debug(expr) abort
  return eval(a:expr)
endfunction

" # Python version {{{2
function! s:UsingPython2() abort
  if has('python')
    return 1
  endif
  return 0
endfunction

let s:using_python2 = s:UsingPython2()
let s:python_command = s:using_python2 ? 'python ' : 'python3 '
let s:pyfile_command = s:using_python2 ? 'pyfile ': 'py3file '

"------------------------------------------------------------------------
" ## lh functions {{{1
" Function: jira#lh_option_get(name, default [, scope])            {{{2
" @return b:{name} if it exists, or g:{name} if it exists, or {default}
" otherwise
" The order of the variables checked can be specified through the optional
" argument {scope}
function! jira#lh_option_get(name,default,...) abort
  let l:scope = (a:0 == 1) ? a:1 : 'bg'
  let l:name = a:name
  let l:i = 0
  while l:i != strlen(l:scope)
    if exists(l:scope[l:i].':'.l:name)
      " \ && (0 != strlen({scope[i]}:{name}))
      " This syntax doesn't work with dictionaries -> !exe
      " return {scope[i]}:{name}
      exe 'return '.l:scope[l:i].':'.l:name
    endif
    let l:i += 1
  endwhile
  return a:default
endfunction

" Function: jira#lh_common_warning_msg {{{2
function! jira#lh_common_warning_msg(text) abort
  echohl WarningMsg
  " echomsg a:text
  call jira#lh_common_echomsg_multilines(a:text)
  echohl None
endfunction

" Function: jira#lh_common_echomsg_multilines {{{2
function! jira#lh_common_echomsg_multilines(text) abort
  let l:lines = type(a:text) == type([]) ? a:text : split(a:text, "[\n\r]")
  for l:line in l:lines
    echomsg l:line
  endfor
endfunction

function! jira#lh_get_current_keyword() abort
  let l:c = col ('.')-1
  let l:l = line('.')
  let l:ll = getline(l:l)
  let l:ll1 = strpart(l:ll,0,l:c)
  let l:ll1 = matchstr(l:ll1,'\k*$')
  if strlen(l:ll1) == 0
    return l:ll1
  else
    let l:ll2 = strpart(l:ll,l:c,strlen(l:ll)-l:c+1)
    let l:ll2 = matchstr(l:ll2,'^\k*')
    " let ll2 = strpart(ll2,0,match(ll2,'$\|\s'))
    return l:ll1.l:ll2
  endif
endfunction
"------------------------------------------------------------------------
" ## Exported functions {{{1
" # Issues lists {{{2
" Function: jira#_do_fetch_issues() {{{3
function! jira#_do_fetch_issues() abort
  if s:py_script_timestamp == 0
    call jira#_init_python()
  endif
  let l:url = jira#lh_option_get('jiracomplete_url', '')
  if len(l:url) == 0
    throw 'Error: [bg]:jiracomplete_url is not specified'
  endif
  let l:email = jira#lh_option_get('jiracomplete_email', '')
  if len(l:email) == 0
    throw 'Error: [bg]:jiracomplete_email is not specified'
  endif
  let l:jql = jira#lh_option_get('jiracomplete_jql', 'assignee=${user}+and+resolution=unresolved')
  let l:token = jira#_get_token(l:email)
  let l:issues = ['Python query was not executed']
  exec s:python_command "vim.command('let l:issues=['+jira_complete(vim.eval('url'), vim.eval('email'), vim.eval('token'), jql=vim.eval('jql'))+']')"
  if len(l:issues) == 1 && type(l:issues[0])==type('')
    throw l:issues[0]
  else
    return l:issues
  endif
endfunction

" Function: jira#get_issues() {{{3
" First from the cache, unless the cache is empty
if !exists('s:cached_issues')
  let s:cached_issues = []
endif

function! jira#get_issues(force_update) abort
  if empty(s:cached_issues) || a:force_update
    let s:cached_issues = jira#_do_fetch_issues()
  endif
  return s:cached_issues
endfunction

" # Completion {{{2
" Function: jira#_complete([force_update_cache]) {{{3
function! jira#_complete(...) abort
  let l:issues = jira#get_issues(a:0 ? a:1 : 0)
  " Hint: let g:jiracomplete_format = 'v:val.abbr . " -> " . v:val.menu'
  let l:format = jira#lh_option_get('jiracomplete_format', 'v:val.abbr')
  call map(l:issues, "extend(v:val, {'word': ".l:format.'})')
  let l:lead = jira#lh_get_current_keyword() " From lh-vim-lib
  call filter(l:issues, 'v:val.abbr =~ l:lead')
  if !empty(l:issues)
    call complete(col('.')-len(l:lead), l:issues)
  else
    call jira#lh_common_warning_msg('No Issue ID starting with '.l:lead)
  endif
  return ''
endfunction

"------------------------------------------------------------------------
" ## Internal functions {{{1

" # Python module init {{{2
" Function: jira#_init_python() {{{3
" The Python module will be loaded only if it has changed since the last time
" this autoload plugin has been sourced. It is of course loaded on the first
" time. Note: this feature is to help maintain the plugin.
let s:py_script_timestamp = 0
let s:plugin_root_path    = expand('<sfile>:p:h:h')
let s:jirapy_script      = s:plugin_root_path . '/py/vimjira.py'
function! jira#_init_python() abort
  if !filereadable(s:jirapy_script)
    throw 'Cannot find vim-jira python script: '.s:jirapy_script
  endif
  let l:ts = getftime(s:jirapy_script)
  if s:py_script_timestamp >= l:ts
    return
  endif
  " jira_complete python part is expected to be already initialized
  call jira#verbose('Importing '.s:jirapy_script)
  exe s:python_command ' import sys'
  exe s:python_command 'sys.path = ["' . s:plugin_root_path . '"] + sys.path'
  exe s:pyfile_command s:jirapy_script
  let s:py_script_timestamp = l:ts
endfunction

" # Options related functions {{{2
" Function: jira#_get_password() {{{3
function! jira#_get_token(email) abort
  let l:token = jira#lh_option_get('jiracomplete_token', '')
  if len(l:token) == 0
    call inputsave()
    let l:otken = inputsecret('Please input jira token for '.a:email.': ')
    " The token is voluntarilly not cached in case the end user wants to
    " keep its privacy
    call inputrestore()
    echohl None
  endif
  return l:token
endfunction

"------------------------------------------------------------------------
" ## Initialize module  {{{1
call jira#_init_python()
"------------------------------------------------------------------------
" }}}1
let &cpoptions=s:cpo_save
"=============================================================================
" vim600: set fdm=marker:
