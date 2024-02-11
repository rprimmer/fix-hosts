
MANPAGE = fix-hostfiles.1
PROG    = fix-hostfiles.sh
# homebrew has different paths on Intel and ARM macs
# BINDIR  = /usr/local/bin
# MANDIR  = /usr/local/share/man/man1
BINDIR  = /opt/homebrew/bin
MANDIR  = /opt/homebrew/share/man/man

prog: $(PROG)
	cp $(PROG) $(BINDIR)
	chmod 755 $(BINDIR)/$(PROG)

man: $(MANPAGE)
	cp $(MANPAGE) $(MANDIR)
