set encoding=utf-8
scriptencoding utf-8
" ============================================================================
"  ~/.vimrc — 乾淨、可攜、無外掛的 Vim 設定（user 與 root 共用同一份）
"  來源：https://github.com/fdff87554/misc/blob/main/configs/vim/.vimrc
"  目標：Vim 9.x（Ubuntu / Debian / Kali / macOS），Ghostty 終端，常透過 tmux / SSH 使用
"  搭配：misc/configs/tmux/.tmux.conf（focus-events、COLORTERM、OSC52）
"
"  注意：map 指令的同一行後面不能接 " 註解（會被當成按鍵的一部分），
"        所有註解一律獨立成行。
" ============================================================================

" ---------------------------------------------------------------------------
" 0. Vim 內建的 sensible defaults，之後再覆蓋
"    （backspace、showcmd、ttimeout、開檔跳回上次游標位置、:DiffOrig 等）
" ---------------------------------------------------------------------------
unlet! skip_defaults_vim
silent! source $VIMRUNTIME/defaults.vim

" ---------------------------------------------------------------------------
" 1. 一般行為
" ---------------------------------------------------------------------------
set history=500
" 允許未存檔的 buffer 被隱藏切換；有未存檔變動時用對話框詢問而非報錯
set hidden
set confirm
set mouse=a
set belloff=all
set nojoinspaces
set lazyredraw

" 檔案在外部被改動時自動重讀（tmux 內需 focus-events on 才會觸發 FocusGained）
set autoread
augroup AutoReload
  autocmd!
  autocmd FocusGained,BufEnter * silent! checktime
augroup END

" ---------------------------------------------------------------------------
" 2. 介面 / 外觀
" ---------------------------------------------------------------------------
set number
set cursorline
set scrolloff=7
set sidescrolloff=5
set title
set laststatus=2
set wildmenu
set wildmode=longest:full,full
set shortmess+=I
" 顯示 Tab 與行尾空白（YAML / Makefile 很有用）；<leader>l 切換
set list
set listchars=tab:»\ ,trail:·,nbsp:␣
" 狀態列：檔名 / 修改旗標 / 檔案類型 / 編碼 / 換行格式 / 行,欄 / 百分比
set statusline=%<%f\ %h%m%r%=%y\ %{&fenc!=#''?&fenc:&enc}\ %{&ff}\ \ %-10(%l,%c%)\ %P

" Truecolor：Ghostty 直連，或 tmux 內（tmux.conf 設了 COLORTERM=truecolor）
if has('termguicolors') && ($COLORTERM =~# '\v(truecolor|24bit)' || $TERM =~# 'ghostty')
  " 讓 termguicolors 在 tmux 內也能正確送出 RGB 序列
  let &t_8f = "\<Esc>[38;2;%lu;%lu;%lum"
  let &t_8b = "\<Esc>[48;2;%lu;%lu;%lum"
  set termguicolors
endif
" 不指定 colorscheme，讓 Ghostty 的背景透出，只靠 syntax 高亮

" ---------------------------------------------------------------------------
" 3. 搜尋
" ---------------------------------------------------------------------------
set incsearch
set hlsearch
set ignorecase
" 搜尋字串含大寫時才區分大小寫
set smartcase

" ---------------------------------------------------------------------------
" 4. 縮排 / Tab（預設 4 空白；各檔案類型於第 7 區覆蓋）
" ---------------------------------------------------------------------------
set expandtab
set tabstop=4
set shiftwidth=4
set softtabstop=4
set shiftround
" 不開 smartindent：filetype indent 對各語言更準確
set autoindent

" ---------------------------------------------------------------------------
" 5. 換行顯示（只影響顯示，不會在檔案中插入換行）
" ---------------------------------------------------------------------------
set wrap
set linebreak
" 折行時保留原本的縮排
set breakindent
set textwidth=0

" ---------------------------------------------------------------------------
" 6. 檔案 / swap / undo
" ---------------------------------------------------------------------------
" 不留 backup 檔；保留 writebackup（預設）：寫檔中途失敗時原檔不會毀損，寫完即刪
set nobackup

" swap 與 undo 集中放在 ~/.vim，不在專案目錄留下 .swp
"   swap：當機可救回；同一檔案被兩處同時編輯（例如 user 與 root）時會警告
"   undo：關掉檔案後仍可復原
let s:vimdir = expand('~/.vim')
for s:sub in ['swap', 'undodir']
  if !isdirectory(s:vimdir . '/' . s:sub)
    silent! call mkdir(s:vimdir . '/' . s:sub, 'p', 0700)
  endif
endfor
let &directory = s:vimdir . '/swap//'
if has('persistent_undo')
  let &undodir = s:vimdir . '/undodir'
  set undofile
endif

" 敏感檔案不留 swap / undo（避免舊內容以明文殘留在 ~/.vim）
augroup SensitiveFiles
  autocmd!
  autocmd BufReadPre,BufNewFile *.env,.env.*,*secret*,*credential*,*.key,*.pem,*.p12,*.gpg,*/.ssh/*,/tmp/*,/var/tmp/*,/dev/shm/*
        \ setlocal noundofile noswapfile
augroup END

set wildignore=*.o,*.obj,*.pyc,*.class,*.swp,*~,*/.git/*,*/node_modules/*,*/__pycache__/*

" ---------------------------------------------------------------------------
" 7. 語法 / 檔案類型
" ---------------------------------------------------------------------------
syntax enable
filetype plugin indent on
" 拼字檢查時不把中日韓文字標成錯字
set spelllang=en,cjk

augroup FiletypeTweaks
  autocmd!
  " Makefile 必須用真 Tab
  autocmd FileType make setlocal noexpandtab
  " 這些格式慣用 2 空白；sh 對齊 personal-setup 的 shfmt -i 2
  autocmd FileType yaml,json,html,css,scss,javascript,typescript,vue,sh,bash
        \ setlocal shiftwidth=2 tabstop=2 softtabstop=2
  " commit message：72 字自動換行、第 73 欄標線、拼字檢查
  autocmd FileType gitcommit setlocal textwidth=72 colorcolumn=73 spell
augroup END

" ---------------------------------------------------------------------------
" 8. 系統剪貼簿：y 的內容自動同步到系統剪貼簿（d / x 不會）
"    有可用的 +clipboard（如 macOS）→ 直接寫入；否則（多數 Linux / SSH）→ OSC52
"    交給終端處理（Ghostty 支援；tmux 需 set-clipboard on）
" ---------------------------------------------------------------------------
function! s:CopyToSystemClipboard(event) abort
  if a:event.operator !=# 'y' || a:event.regname !=# ''
    return
  endif
  if has('clipboard') && (has('mac') || !empty($DISPLAY) || !empty($WAYLAND_DISPLAY))
    call setreg('+', a:event.regcontents, a:event.regtype)
  elseif exists('*echoraw')
    " base64 | tr 寫法在 GNU 與 BSD (macOS) 都可用
    let l:b64 = system('base64 | tr -d "\n"', join(a:event.regcontents, "\n"))
    call echoraw("\<Esc>]52;c;" . l:b64 . "\x07")
  endif
endfunction

augroup SystemClipboard
  autocmd!
  autocmd TextYankPost * call s:CopyToSystemClipboard(v:event)
augroup END

" ---------------------------------------------------------------------------
" 9. 鍵位　Leader = 空白鍵
" ---------------------------------------------------------------------------
let mapleader = ' '
let maplocalleader = ' '

" 清除搜尋反白
nnoremap <silent> <leader><space> :nohlsearch<CR>
" 快速存檔
nnoremap <leader>w :write<CR>
" 切換拼字檢查
nnoremap <leader>s :setlocal spell!<CR>
" 切換顯示 Tab / 行尾空白
nnoremap <leader>l :set list!<CR>
" Y = 複製到行尾（與 D、C 一致）
nnoremap Y y$
" 搜尋結果置中
nnoremap n nzzzv
nnoremap N Nzzzv
" 視覺模式縮排後保持選取
xnoremap < <gv
xnoremap > >gv
" Ctrl+hjkl 切換分割視窗（原本 Ctrl+L 的重繪改用 :redraw!）
nnoremap <C-h> <C-w>h
nnoremap <C-j> <C-w>j
nnoremap <C-k> <C-w>k
nnoremap <C-l> <C-w>l
" 新分割視窗開在下方 / 右方
set splitbelow
set splitright
