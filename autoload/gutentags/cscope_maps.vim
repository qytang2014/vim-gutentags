" cscope_maps module for Gutentags

if !has('nvim') || !exists(":Cscope")
    throw "Can't enable the cscope_maps module for Gutentags, this Vim has ".
                \"no support for cscope_maps files."
endif

" Global Options {{{
let g:gutentags_gtags_cscope = get(g:, 'gutentags_gtags_cscope', 1)
if g:gutentags_gtags_cscope
    let g:gutentags_gtags_executable = 'gtags'
    if !exists('g:gutentags_gtags_dbpath')
        let g:gutentags_gtags_dbpath = ''
    endif

    if !exists('g:gutentags_gtags_options_file')
        let g:gutentags_gtags_options_file = '.gutgtags'
    endif

    if !exists('g:gutentags_gtags_cscope_executable')
        let g:gutentags_gtags_cscope_executable = 'gtags-cscope'
    endif
    let g:gutentags_cscope_build_inverted_index_maps = 0
else
    if !exists('g:gutentags_cscope_executable_maps')
        let g:gutentags_cscope_executable_maps = 'cscope'
    endif

    if !exists('g:gutentags_scopefile_maps')
        let g:gutentags_scopefile_maps = 'cscope.out'
    endif

    if !exists('g:gutentags_cscope_build_inverted_index_maps')
        let g:gutentags_cscope_build_inverted_index_maps = 0
    endif
endif

" }}}

" Gutentags Module Interface {{{
if g:gutentags_gtags_cscope
    let s:runner_exe = gutentags#get_plat_file('update_gtags')
else
    let s:runner_exe = gutentags#get_plat_file('update_scopedb')
endif

let s:unix_redir = (&shellredir =~# '%s') ? &shellredir : &shellredir . ' %s'
let s:added_dbs = []

function! gutentags#cscope_maps#init(project_root) abort
    if g:gutentags_gtags_cscope
        let l:db_path = gutentags#get_cachefile(
                \a:project_root, g:gutentags_gtags_dbpath)
        let l:db_path = gutentags#stripslash(l:db_path)
        let l:dbfile_path = l:db_path . '/GTAGS'
        let l:dbfile_path = gutentags#normalizepath(l:dbfile_path)

        if !isdirectory(l:db_path)
            call mkdir(l:db_path, 'p')
        endif

        " The combination of gtags-cscope, vim's cscope and global files is
        " a bit flaky. Environment variables are safer than vim passing
        " paths around and interpreting input correctly.
        let $GTAGSDBPATH = l:db_path
        let $GTAGSROOT = a:project_root
    else
        let l:dbfile_path = gutentags#get_cachefile(
                    \a:project_root, g:gutentags_scopefile_maps)
    endif
    let b:gutentags_files['cscope_maps'] = l:dbfile_path

endfunction

function! gutentags#cscope_maps#generate(proj_dir, tags_file, gen_opts) abort
    if g:gutentags_gtags_cscope
        let l:cmd = [s:runner_exe]
        let l:cmd += ['-e', '"' . g:gutentags_gtags_executable . '"']

        let l:file_list_cmd = gutentags#get_project_file_list_cmd(a:proj_dir)
        if !empty(l:file_list_cmd)
            let l:cmd += ['-L', '"' . l:file_list_cmd . '"']
        endif

        let l:proj_options_file = a:proj_dir . '/' . g:gutentags_gtags_options_file
        if filereadable(l:proj_options_file)
            let l:proj_options = readfile(l:proj_options_file)
            let l:cmd += l:proj_options
        endif

        " gtags doesn't honour GTAGSDBPATH and GTAGSROOT, so PWD and dbpath
        " have to be set
        let l:db_path = fnamemodify(a:tags_file, ':p:h')
        let l:cmd += ['--incremental', '"'.l:db_path.'"']
    else
        let l:cmd = [s:runner_exe]
        let l:cmd += ['-e', g:gutentags_cscope_executable_maps]
        let l:cmd += ['-p', a:proj_dir]
        let l:cmd += ['-f', a:tags_file]
        let l:file_list_cmd =
            \ gutentags#get_project_file_list_cmd(a:proj_dir)
        if !empty(l:file_list_cmd)
            let l:cmd += ['-L', '"' . l:file_list_cmd . '"']
        endif
        if g:gutentags_cscope_build_inverted_index_maps
            let l:cmd += ['-I']
        endif
    endif
    let l:cmd = gutentags#make_args(l:cmd)

    call gutentags#trace("Running: " . string(l:cmd))
    call gutentags#trace("In:      " . getcwd())
    if !g:gutentags_fake
        let l:job_opts = gutentags#build_default_job_options('cscope_maps')
        let l:job = gutentags#start_job(l:cmd, l:job_opts)
        " Change cscope_maps db_file to gutentags' tags_file
        " Useful for when g:gutentags_cache_dir is used.
        let g:cscope_maps_db_file = a:tags_file
        call gutentags#add_job('cscope_maps', a:tags_file, l:job)
    else
        call gutentags#trace("(fake... not actually running)")
    endif
endfunction

function! gutentags#cscope_maps#on_job_exit(job, exit_val) abort
    let l:job_idx = gutentags#find_job_index_by_data('cscope_maps', a:job)
    let l:dbfile_path = gutentags#get_job_tags_file('cscope_maps', l:job_idx)
    call gutentags#remove_job('cscope_maps', l:job_idx)

    if a:exit_val == 0
        call gutentags#trace("NOOP! cscope_maps does not need add or reset command")
    elseif !g:__gutentags_vim_is_leaving
        call gutentags#warning(
                    \"cscope job failed, returned: ".
                    \string(a:exit_val))
    endif
endfunction

" }}}
