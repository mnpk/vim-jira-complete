"=============================================================================
" $Id$
" File:         plugin/vim-jira-complete.vim {{{1
" Authors:
"   mnpk <https://github.com/mnpk>, initial author of the plugin, 2014
"   Luc Hermitte, enhancements to the plugin, 2014
" Version:      0.2.0
let s:k_version = 020
"------------------------------------------------------------------------
" Description:
"       Autocomplete plugin from Jira issues.
" }}}1
"=============================================================================

if !has('python')
  echo "Error: Required vim compiled with +python"
  finish
endif

" Avoid global reinclusion {{{1
if &cp || (exists("g:loaded_vim_jira_complete")
      \ && (g:loaded_vim_jira_complete >= s:k_version)
      \ && !exists('g:force_reload_vim_jira_complete'))
  finish
endif
let g:loaded_vim_jira_complete = s:k_version
let s:cpo_save=&cpo
set cpo&vim
" Avoid global reinclusion }}}1
"------------------------------------------------------------------------
" Commands and Mappings {{{1

inoremap <silent> <Plug>JiraCompleteIgnoreCache <c-r>=jira#_complete(1)<cr>
inoremap <silent> <Plug>JiraComplete            <c-r>=jira#_complete(0)<cr>
if !hasmapto('<Plug>JiraComplete', 'i')
  imap <silent> <unique> <F5> <Plug>JiraComplete
endif

command! -nargs=0 JiraCompleteUpdateCache call jira#get_issues(1)
" Commands and Mappings }}}1
"------------------------------------------------------------------------
let &cpo=s:cpo_save
"=============================================================================
" vim600: set fdm=marker:

