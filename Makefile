# Makefile for wl2url
# $Id: Makefile 1215 2012-05-01 07:15:26Z ranga $

PGM_NAME = wl2url
PGM_REL  = 0.3.1
WORKDIR = work
FILES = wl2url.pl wl2url.1 Makefile README.txt

all:
	@echo Nothing to do

tgz:
	/bin/rm -rf $(WORKDIR)
	mkdir -p $(WORKDIR)/$(PGM_NAME)-$(PGM_REL)	
	cp $(FILES) $(WORKDIR)/$(PGM_NAME)-$(PGM_REL)
	cd $(WORKDIR) && \
        tar -cvf ../$(PGM_NAME)-$(PGM_REL).tar $(PGM_NAME)-$(PGM_REL)
	gzip $(PGM_NAME)-$(PGM_REL).tar
	mv $(PGM_NAME)-$(PGM_REL).tar.gz $(PGM_NAME)-$(PGM_REL).tgz

install:
	@echo "Please do the following:"
	@echo
	@echo "mkdir -p ~/bin ~/man/man1"
	@echo "cp $(PGM_NAME) ~/bin"
	@echo "cp $(PGM_NAME).1 ~/man/man1"
	@echo
	@echo "Add ~/bin to PATH and ~/man to MANPATH"

clean:
	/bin/rm -rf *~ .*~ .DS_Store $(WORKDIR) $(PGM_NAME)*.tgz \
                $(PGM_NAME).1.txt $(PGM_NAME)*.asc

man2txt: $(PGM_NAME).1.txt

$(PGM_NAME).1.txt:
	nroff -Tascii -man $(PGM_NAME).1 | col -b -x > $(PGM_NAME).1.txt

