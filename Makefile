
MANPAGE = fix-hostfiles.1
PROG    = fix-hostfiles.sh
BINDIR  = /usr/local/bin
MANDIR	= /usr/local/share/man/man1

prog: $(PROG)
	cp $(PROG) $(BINDIR)
	chmod 755 $(BINDIR)/$(PROG)

man: $(MANPAGE)
	cp $(MANPAGE) $(MANDIR)
