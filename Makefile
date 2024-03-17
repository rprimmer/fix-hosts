
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
	pandoc README.md -o readme.pdf
	pandoc Bash-Design-Spec.md -o bash-design-spec.pdf

man: $(MANPAGE)
	cp $(MANPAGE) $(MANDIR)
