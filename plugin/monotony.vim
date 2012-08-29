" Vim global plugin for automating repetitive coding tasks
" Last Change:  2012 Aug 27
" Maintainer:   Stephen Fiorelli
" License:      This file is placed in the public domain.

if exists("monotony_loaded")
  finish
endif

let g:monotony_loaded = 1

" Handle compatible mode                                                   {{{1
let s:savecpo = &cpo
set cpo&vim

"command! -nargs=* -range Transform <line1>,<line2> call Transform(<f-args>)
command! -nargs=1 -range Fnsort <line1>,<line2> call Fnsort(<f-args>)
fun! Fnsort(type) range
  "Fnsort c/h
  " Search through the text looking for comment blocks. When found wrap the
  " function in start/end delimiters for the next step
  
  let curLineNumber = a:firstline
  " Used to see if we've matched two lines in a row
  let prevMatch = 0
  let matchLineNumberStart = 0
  while curLineNumber < a:lastline
    let line = getline(curLineNumber)
    "let fnmatch = match(line, '\s*\/\/-\+\n\s*\/\/-\+$')
    " Functions are assumed to be delimited by two lines of //---* potentially
    " with doxygen comments in between
    let fnmatch = match(line, '\s*\/\/-\+$')

    if fnmatch >= 0
      if prevMatch == 1
        " Add a marker to the start of the function block
        call setline(matchLineNumberStart, 'FNSTART'.line)

        " C functions end with a }, H functions end with a ;
        if a:type == 'c'
          call search('^{', 'W')
          let lastline = search('^}', 'W')
        else
          let lastline = search(';', 'W')
        endif

        " Add a marker to the end of the function block
        call setline(lastline, getline(lastline).'FNEND')
        let prevMatch = 0
      else
        let matchLineNumberStart = curLineNumber
        let prevMatch = 1
      endif
    endif

    let curLineNumber += 1
  endwhile

  " Join all of the function block text onto one line
  let range = a:firstline . ',' . a:lastline
  exe range . 'g/FNSTART\%[\w]!\=/,/FNEND/ s/$\n/@@@'

  " Find the new line count now that we've deleted a bunch of lines
  exec a:firstline
  let lastline = search('^[^FNSTART]', 'nW') - 1
  if lastline < 0
    let lastline = line('$')
  endif

  " Sort the function text and split the lines back up
  " FNSTART//------@@@//------@@@void@@@fn()@@@{@@@  foo();@@@}FNEND@@@
  let range = a:firstline . ',' . lastline
  if a:type == 'c'
    " Find the first occurrence of a letter/*/& followed by @@@ and sort on
    " the text that follows.
    exe range . "sort/[A-Za-z\|&\|*]@@@/"
  else
    exe range . 'sort/\/\/-\+@@@.*\/\/-\+@@@.\{-}@@@/'
  endif
  exe range . "s/@@@/\\r/g"

  " Delete the delimiters we added earlier
  let range = a:firstline . ',' . a:lastline
  exe range . 's/FN[START\|END]\+'
  "exe range . "s/FNEND//"
endfun

command! -nargs=0 -range FnFormat <line1>,<line2> call FnFormat()
fun! FnFormat()
  " Mark the starting line
  let firstline = line('.')
  if strlen(getline(firstline)) > 80
    " Find the first open paren/equals and add a newline after it
    exe a:firstline . ',' . a:lastline . 's/\([(=]\)/\1\r'
    " Add newlines after every comma in the remaining text
    exe (firstline+1) . ',' . (firstline+1) . 's/,/,\r/eg'
    " Indent the code
    let cmd = '='.(line('.')-firstline).'k'
    exe 'normal! '.cmd
  endif
endfun

command! -nargs=0 -range GSComment <line1>,<line2> call GSComment()
fun! GSComment() range
  " Current line number
  let curline = 0
  " Number of added lines
  let newlines = 0
  let lastline = a:lastline

  " If no range specifed, use whole file
  if a:firstline == 1 && lastline == 1
    let lastline = line('$')
  endif

  while curline <= lastline
    " Mark the curline where the comment should be added 
    let marker = search('/\*\*', 'W')
    " Find the curline with the functon decl
    let curline = search('[G|S]et', 'W')
    " Check if this a get or a set function
    let getfn = match(getline(curline), '^\s*G')

    if marker != 0 && curline >= a:firstline && curline <= lastline+newlines
      " Copy the text after 'G/Set' into a buffer
      normal! 3l
      normal! "ryw

      " Search for one function argument
      let paramMarker = search('\w)', 'W', curline)
      if paramMarker != 0
        normal! b
        normal! "pyw
      endif

      " Jump back to where the comment should be added and add a new line
      exec marker
      let marker += 1
      let newlines += 1
      normal! o

      " Add the param comment if applicable
      if paramMarker != 0
        if getfn == -1
          call setline(marker, getline(marker).' Sets the '.@r)
          let marker += 1
          let newlines += 1
          normal! o
        endif

        call setline(marker, getline(marker).' @param '.@p.' The '.@r)
      endif

      " Add the return comment if applicable
      if getfn > -1
        " If we already added a line for a parameter, add a new line for the
        " return value (otherwise the new line will already be there)
        if paramMarker != 0
          let marker += 1
          let newlines += 1
          normal! o
        endif

        call setline(marker, getline(marker).' @return The '.@r)
      endif
    else
      " Terminate the while loop
      let curline = lastline+1
    endif
  endwhile

endfun

" Handle compatible mode, part 2                                           {{{1
let &cpo = s:savecpo
unlet s:savecpo
