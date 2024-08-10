SPHINX		?= sphinx-build
SERVER		?= python3 -mhttp.server
VENVDIR		?= .venv
VENV		?= $(VENVDIR)/bin/activate

SITEMAP		?= python3 sitemaps.py
URL		?= https://lexbor.com

BUILDDIR	?= build
DEPLOYDIR	?= deploy


.PHONY: install site serve check clean deploy

$(VENVDIR):
	python3 -m venv $(VENVDIR)

install: $(VENVDIR)
	. $(VENV); pip install \
	    --require-virtualenv \
	    --upgrade -r requirements.txt \
        --log .venv/pip_install.log

site: $(VENVDIR) $(BUILDDIR)
	. $(VENV); $(SPHINX) -E -b dirhtml source "$(BUILDDIR)"

$(BUILDDIR):
	mkdir "$(BUILDDIR)"
	mkdir "$(BUILDDIR)/keys/"

serve: SPHINX=sphinx-autobuild
serve: site

check: $(VENVDIR)
	. $(VENV); $(SPHINX) -b linkcheck -d "$(BUILDDIR)/.doctrees" source .

clean-doc:
	rm -rf $(BUILDDIR) $(DEPLOYDIR)

clean: clean-doc
	rm -rf $(VENVDIR)

deploy: site
	$(eval TMP := $(shell mktemp -d))
	curl https://nginx.org/keys/nginx_signing.key | gpg --dearmor \
		| tee "$(BUILDDIR)/keys/nginx-keyring.gpg" > /dev/null
	gpg --dry-run --quiet --import --import-options import-show \
		"$(BUILDDIR)/keys/nginx-keyring.gpg"
	rsync -rv $(EXCLUDE) "$(BUILDDIR)/" "$(TMP)"
	rsync -rcv --delete --exclude='*.gz' --exclude='tmp.*' \
		  --exclude='/sitemap.xml' "$(TMP)/" "$(DEPLOYDIR)"
	$(SITEMAP) "$(URL)" index.html "$(DEPLOYDIR)" -e sitemapexclude.txt \
		> "$(TMP)/sitemap.xml"
	rsync -rcv "$(TMP)/sitemap.xml" "$(DEPLOYDIR)"
	-rm -rf "$(TMP)"
	mkdir $(DEPLOYDIR)/.well-known
	curl -L $(UNIT_SECURITY) -o "$(DEPLOYDIR)/.well-known/security.txt" 2>/dev/null
	chmod -R g=u "$(DEPLOYDIR)"
