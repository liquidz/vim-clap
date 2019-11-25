let s:job_id = -1

function! s:on_exit() abort
  call clap#sign#reset_to_first_line()
  call clap#spinner#set_idle()

  let decoded = json_decode(s:output)
  if decoded.total == 0
    call g:clap.display.set_lines([g:clap_no_matches_msg])
    call clap#indicator#set_matches('[0]')
    call clap#sign#disable_cursorline()
  else
    call clap#impl#refresh_matches_count(string(decoded.total))

    let lines = decoded.lines
    call g:clap.display.set_lines_lazy(lines)

    let indices = decoded.indices
    let hl_lines = indices[:g:clap.display.line_count()-1]
    call clap#impl#add_highlight_for_fuzzy_indices(hl_lines)
  endif
endfunction

if has('nvim')
  function! s:on_event(job_id, data, event) abort
    " We only process the job that was spawned last time.
    if s:job_id == a:job_id
      if a:event ==# 'stdout'
        " Second last is the real last one for neovim.
        let output = a:data[:-2]
        if !empty(output)
          let s:output = output[0]
        endif
      elseif a:event ==# 'stderr'
        " Ignore the error
      else
        call s:on_exit()
      endif
    endif
  endfunction

  function! s:job_start(cmd) abort
    " We choose the lcd way instead of the cwd option of job for the
    " consistence purpose.
    let job_opts = {
          \ 'on_exit': function('s:on_event'),
          \ 'on_stdout': function('s:on_event'),
          \ 'on_stderr': function('s:on_event'),
          \ 'stdout_buffered': v:true,
          \ }
    let s:job_id = clap#job#start(a:cmd, job_opts)
  endfunction
else
  function! s:close_cb(channel) abort
    if clap#job#vim8_job_id_of(a:channel) == s:job_id
      " https://github.com/vim/vim/issues/5143
      let s:output = split(ch_readraw(a:channel), "\n")[0]
      call s:on_exit()
    endif
  endfunction

  function! s:job_start(cmd) abort
    let s:job_id = clap#job#start(a:cmd, {
          \ 'in_io': 'null',
          \ 'close_cb': function('s:close_cb'),
          \ 'noblock': 1,
          \ 'mode': 'raw',
          \ })
  endfunction
endif

function! clap#maple#job_start(cmd) abort
  if s:job_id != -1
    call clap#job#stop(s:job_id)
    let s:job_id = -1
  endif
  let s:output = v:null
  call s:job_start(a:cmd)
endfunction
