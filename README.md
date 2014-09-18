# vim-jira-complete

`jira-complete` is a Vim plugin that queries JIRA issues and make a AutoComplete list for you. 

This will be helpful if you are using Jira with DVCS smart commits and [Fugitive.vim](https://github.com/tpope/vim-fugitive)
## Demo

![demo](jira-complete-demo.gif)

## How to use

\<F5\> in insert mode.

## Installation

Use [Vundle](https://github.com/gmarik/Vundle.vim).

or,

```
cd ~/.vim/bundle
git clone git://github.com/mnpk/vim-jira-complete.git
```

## Dependency

python support and [requests](http://docs.python-requests.org/) package.

```
pip install requests
```

## Settings

in your .vimrc,

```
let g:jiracomplete_url = 'http://your.jira.url/here/'
let g:jiracomplete_username = 'your_jira_username'
```
