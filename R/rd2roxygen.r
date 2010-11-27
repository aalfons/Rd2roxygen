# ESS users may use options(roxygen.comment = "##' ")

# Parse input Rd file -------------------------------------------------------
parse_file <- function(path) {
  rd <- tools::parse_Rd(path)

  tags <- sapply(rd, tag)
  tags <- gsub("\\\\", "", tags)
  names(rd) <- tags

  # Remove top-level text strings - just line breaks between sections
  rd <- rd[tags != "TEXT"]

  out <- list()
  # Title, description, value and examples, need to be stitched into a 
  # single string.
  out$title <- reconstruct(untag(rd$title))
  out$docType <- reconstruct(untag(rd$docType))
  out$usage <- reconstruct(untag(rd$usage))
  out$desc <- gsub("$\n+|\n+^", "", reconstruct(untag(rd$description)))
  out$details <- reconstruct(untag(rd$details))
  out$format <- reconstruct(untag(rd$format))
  out$value <- reconstruct(untag(rd$value))
  out$note <- reconstruct(untag(rd$note))
  out$author <- gsub('@', '@@', reconstruct(untag(rd$author)))
  out$seealso <- reconstruct(untag(rd$seealso))
  out$references <- reconstruct(untag(rd$references))
  out$source <- reconstruct(untag(rd$source))

  out$examples <- reconstruct(untag(rd$examples))

  # Join together aliases and keywords
  out$name <- reconstruct(untag(rd$name))
  out$aliases <- unname(sapply(rd[names(rd) == "alias"], "[[", 1))
  # If the only alias is the name, then skip it
  if (identical(out$aliases, out$name)) {
    out$aliases <- NULL
  }
  out$keywords <- unname(sapply(rd[names(rd) == "keyword"], "[[", 1))

  # Pull apart arguments
  arguments <- rd$arguments
  arguments <- arguments[sapply(arguments, tag) != "TEXT"]
  out$params <- sapply(arguments, function(argument) {
    paste(if (tag(argument[[1]][[1]]) == "\\dots") 
		"\\dots" else argument[[1]], 
	reconstruct(argument[[2]]))
  })
  
  out
}

# Create output --------------------------------------------------------------
create_roxygen <- function(info, usage = FALSE) {
  c(
    comment_line(info$title),
    comment_line(info$desc),
    comment_line(),
    comment_line(info$details),
    comment_line(),
	if (!is.null(info$docType) && 
		(info$docType %in% c('package', 'data', 'methods', 'class')))
			comment_tag("@name", info$name), 
    comment_tag("@aliases", paste(info$aliases, collapse = " ")),
    comment_tag("@docType", info$docType),
	if (usage) comment_tag("@usage", info$usage),
    comment_tag("@param", info$params),
    comment_tag("@format", info$format),
    comment_tag("@return", info$value),
    comment_tag("@note", info$note),
    comment_tag("@author", info$author),
    comment_tag("@seealso", info$seealso),
    comment_tag("@references", info$references),
    comment_tag("@source", info$source),
    comment_tag("@keywords", paste(info$keywords, collapse = " ")),
    if (!is.null(info$examples)) {
      c(
        comment_line("@examples\n"), 
        paste(comment_prefix(), 
			gsub("\n", paste("\n", comment_prefix(), sep = ""), 
				info$examples), 
			sep = "")
      )
    },
    "\n"
  )
}

parse_and_save <- function(path, file, usage = FALSE) {
  parsed <- parse_file(path)
  output <- create_roxygen(parsed, usage = usage)
  if (missing(file)) output else
	cat(paste(output, collapse = "\n"), file = file)
}

Rd2roxygen <- function(pkg, nomatch, usage = FALSE) {
	if (!all(c('man', 'R') %in% list.files(pkg)))
		stop("'pkg' has to be the root directory of a source package")
	man.dir <- file.path(pkg, 'man')
	R.dir <- file.path(pkg, 'R')
	files <- list.files(man.dir, '\\.[Rr]d$')
	if (missing(nomatch)) 
		nomatch <- paste(basename(pkg), '-package.R', sep = '')
	unlink(p <- file.path(R.dir, nomatch))
	for (f in files) {
		timestamp()
		parsed <- parse_file(file.path(man.dir, f))
		Rd <- create_roxygen(parsed, usage = usage)
		Rd <- Rd[Rd != '\n']
		message('parsed: ', f)
		fname <- parsed$name
		tryf <- paste(fname, c('.R', '.r'), sep = '')
		tryf <- unique(c(tryf[file.exists(file.path(R.dir, tryf))], 
				list.files(R.dir, '\\.[Rr]$')))
		idx <- integer(0)
		message("looking for the object '", fname, "' in:")
		for (i in tryf) {
			r <- file.path(R.dir, i)
			idx <- grep(sprintf('^[[:space:]]*(`|)(%s)(`|)[[:space:]]*(<-|=)', 
				gsub('\\.', '\\\\.', fname)), 
			(r.Rd <- readLines(r, warn = FALSE)))
			message('  ', i, ': ', appendLF = FALSE)
			message(ifelse(length(idx), paste('row', idx), 'not found'))
			if (length(idx)) break
		}
		if (length(idx)) {
			cat(append(r.Rd, c('\n', Rd), idx - 1), file = r, sep = '\n')
			message(r, ' updated')
		} else {
			cat(c('\n', Rd, 'NULL'), '\n\n', file = p, sep = '\n', append = TRUE)
			message("unmatched object '", fname, "' written into ", p)
		}
		message('\n')
		if (.Platform$OS.type == 'windows') {
			flush.console()
		}
	}
}
