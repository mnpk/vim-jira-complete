"=============================================================================
" $Id$
" File:         vim-jira-complete/autoload/jira.vim {{{1
" Authors:
"   mnpk <https://github.com/mnpk>, initial author of the plugin, 2014
"   Luc Hermitte, enhancements to the plugin, 2014
"   jira#lh_... functions are copied from Luc Hermitte's vim library [lh-vim-lib](http://code.google.com/p/lh-vim/wiki/lhVimLib).
" Version:      0.2.0
let s:k_version = 020
"------------------------------------------------------------------------
" Description:
"       Internals and API functions for vim-jira-complete
" }}}1
"=============================================================================

let s:cpo_save=&cpo
set cpo&vim
"------------------------------------------------------------------------
" ## Misc Functions     {{{1
" # Version {{{2
function! jira#version()
  return s:k_version
endfunction

" # Debug   {{{2
if !exists('s:verbose')
  let s:verbose = 0
endif
function! jira#verbose(...)
  if a:0 > 0 | let s:verbose = a:1 | endif
  return s:verbose
endfunction

function! s:Verbose(expr)
  if s:verbose
    echomsg a:expr
  endif
endfunction

function! jira#debug(expr)
  return eval(a:expr)
endfunction


"------------------------------------------------------------------------
" ## lh functions {{{1
" Function: jira#lh_option_get(name, default [, scope])            {{{2
" @return b:{name} if it exists, or g:{name} if it exists, or {default}
" otherwise
" The order of the variables checked can be specified through the optional
" argument {scope}
function! jira#lh_option_get(name,default,...)
  let scope = (a:0 == 1) ? a:1 : 'bg'
  let name = a:name
  let i = 0
  while i != strlen(scope)
    if exists(scope[i].':'.name)
      " \ && (0 != strlen({scope[i]}:{name}))
      " This syntax doesn't work with dictionaries -> !exe
      " return {scope[i]}:{name}
      exe 'return '.scope[i].':'.name
    endif
    let i += 1
  endwhile 
  return a:default
endfunction

" Function: jira#lh_common_warning_msg {{{2
function! jira#lh_common_warning_msg(text)
  echohl WarningMsg
  " echomsg a:text
  call jira#lh_common_echomsg_multilines(a:text)
  echohl None
endfunction 

" Function: jira#lh_common_echomsg_multilines {{{2
function! jira#lh_common_echomsg_multilines(text)
  let lines = type(a:text) == type([]) ? a:text : split(a:text, "[\n\r]")
  for line in lines
    echomsg line
  endfor
endfunction

function! jira#lh_get_current_keyword()
  let c = col ('.')-1
  let l = line('.')
  let ll = getline(l)
  let ll1 = strpart(ll,0,c)
  let ll1 = matchstr(ll1,'\k*$')
  if strlen(ll1) == 0
    return ll1
  else
    let ll2 = strpart(ll,c,strlen(ll)-c+1)
    let ll2 = matchstr(ll2,'^\k*')
    " let ll2 = strpart(ll2,0,match(ll2,'$\|\s'))
    return ll1.ll2
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
  let url = jira#lh_option_get('jiracomplete_url', '')
  if len(url) == 0
    throw "Error: [bg]:jiracomplete_url is not specified"
  endif
  let username = jira#lh_option_get('jiracomplete_username', '')
  if len(username) == 0
    throw "Error: [bg]:jiracomplete_username is not specified"
  endif
  let password = jira#_get_password(username)
  py vim.command('let issues=['+jira_complete(vim.eval('url'), vim.eval('username'), vim.eval('password'))+']')
  if len(issues) == 1 && type(issues[0])==type('')
    throw issues
  else
    return issues
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
  let issues = jira#get_issues(a:0 ? a:1 : 0)
  " Hint: let g:jiracomplete_format = 'v:val.abbr . " -> " . v:val.menu'
  let format = jira#lh_option_get('jiracomplete_format', "v:val.abbr")
  call map(issues, "extend(v:val, {'word': ".format.'})')
  let lead = jira#lh_get_current_keyword() " From lh-vim-lib
  call filter(issues, 'v:val.abbr =~ lead')
  if !empty(issues)
    call complete(col('.')-len(lead), issues)
  else
    call jira#lh_common_warning_msg("No Issue ID starting with ".lead)
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
    throw "Cannot find vim-jira python script: ".s:jirapy_script
  endif
  let ts = getftime(s:jirapy_script)
  if s:py_script_timestamp >= ts
    return
  endif
  " jira_complete python part is expected to be already initialized
  call jira#verbose("Importing ".s:jirapy_script)
  python import sys
  exe 'python sys.path = ["' . s:plugin_root_path . '"] + sys.path'
  exe 'pyfile ' . s:jirapy_script
  let s:py_script_timestamp = ts
endfunction

" # Options related functions {{{2
" Function: jira#_get_password() {{{3
function! jira#_get_password(username)
  let password = jira#lh_option_get('jiracomplete_password', '')
  if len(password) == 0
    call inputsave()
    let password = inputsecret('Please input jira password for '.a:username.': ')
    " The password is voluntarilly not cached in case the end user wants to
    " keep its privacy
    call inputrestore()
    echohl None
  endif
  return password
endfunction

"------------------------------------------------------------------------
" ## Initialize module  {{{1
call jira#_init_python()
"------------------------------------------------------------------------
" }}}1
let &cpo=s:cpo_save
"=============================================================================
" vim600: set fdm=marker:
