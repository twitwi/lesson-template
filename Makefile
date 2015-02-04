# R Markdown files.
SRC_RMD = $(wildcard ??-*.Rmd)
DST_RMD = $(patsubst %.Rmd,%.md,$(SRC_RMD))

# All Markdown files (hand-written and generated).
ALL_MD = $(wildcard *.md) $(DST_RMD)
SRC_MD = index.md \
	 $(sort $(wildcard ??-*.md)) \
	 $(DST_RMD) \
	 motivation.md \
	 reference.md \
	 discussion.md \
	 instructors.md
DST_HTML = $(patsubst %.md,%.html,$(SRC_MD))

# All outputs.
DST_ALL = $(DST_HTML)

# Pandoc filters.
FILTERS = $(wildcard tools/filters/*.py)

# Temporary file for all-in-one
ALL_IN_ONE_MD=all-in-one.md
ALL_IN_ONE_HTML=all-in-one.html
ALL_IN_ONE_EPUB=all-in-one.epub
ALL_IN_ONE_LATEX=all-in-one.tex
ALL_IN_ONE_PDF=all-in-one.pdf

# Inclusions.
INCLUDES = \
	-Vheader="$$(cat _includes/header.html)" \
	-Vbanner="$$(cat _includes/banner.html)" \
	-Vfooter="$$(cat _includes/footer.html)" \
	-Vjavascript="$$(cat _includes/javascript.html)"

# Chunk options for knitr (used in R conversion).
R_CHUNK_OPTS = tools/chunk-options.R

# Ensure that intermediate (generated) Markdown files from R are kept.
.SECONDARY: $(DST_RMD)

# Default action is to show what commands are available.
all : commands

## check    : Validate all lesson content against the template.
check: $(ALL_MD)
	python tools/check.py .

## clean    : Clean up temporary and intermediate files.
clean :
	@rm -rf $$(find . -name '*~' -print)

## preview  : Build website locally for checking.
preview : $(DST_ALL)

# Pattern for slides (different parameters and template).
motivation.html : motivation.md _layouts/slides.html
	pandoc -s -t html \
	--template=_layouts/slides \
	-o $@ $<

# Pattern to build a generic page.
%.html : %.md _layouts/page.html $(FILTERS)
	pandoc -s -t html \
	--template=_layouts/page \
	--filter=tools/filters/blockquote2div.py \
	--filter=tools/filters/id4glossary.py \
	$(INCLUDES) \
	-o $@ $<

## epub     : Build epub version of lesson. (Experimental)
epub: ${ALL_IN_ONE_EPUB}

## pdf      : Build pdf version of lesson. (Experimental)
pdf: ${ALL_IN_ONE_PDF}

# Create all in one version of the lesson
#
# THIS IS EXPERIMENTAL.
${ALL_IN_ONE_MD}: ${SRC_MD} LICENSE.md
	cp METADATA $@
	for file in $^; \
	    do \
	    pandoc -t markdown \
	    --template=_layouts/page \
	    $${file} \
	    >> $@; \
	    echo >> $@; \
	    done

${ALL_IN_ONE_HTML}: ${ALL_IN_ONE_MD}
	pandoc -s -f markdown -t html \
	    --template=_layouts/page \
	    --filter=tools/filters/blockquote2div.py \
	    --filter=tools/filters/id4glossary.py \
	    --filter=tools/filters/epub.py \
	    $(INCLUDES) \
	    -o $@ $<

${ALL_IN_ONE_EPUB}: ${ALL_IN_ONE_MD}
	pandoc -f markdown -t epub \
	    --filter=tools/filters/id4glossary.py \
	    --filter=tools/filters/epub.py \
	    -o $@ $<

${ALL_IN_ONE_LATEX}: ${ALL_IN_ONE_MD}
	pandoc -f markdown -t latex \
	    --template=_layouts/book \
	    --standalone \
	    --chapters \
	    --listings \
	    -o $@ $<
	sed -i \
	    -e 's/\.gif//g' \
	    -e 's/\.svg//g' \
	    $@
	for image in $$(find . -name '*.gif'); \
	do \
	    convert $${image} $${image/gif/png}; \
	done
	for image in $$(find . -name '*.svg'); \
	do \
	    convert $${image} $${image/svg/png}; \
	done

${ALL_IN_ONE_PDF}: ${ALL_IN_ONE_LATEX}
	latexmk -pdf $<

# Pattern to convert R Markdown to Markdown.
%.md: %.Rmd $(R_CHUNK_OPTS)
	Rscript -e "knitr::knit('$$(basename $<)', output = '$$(basename $@)')"

## commands : Display available commands.
commands : Makefile
	@sed -n 's/^##//p' $<

## settings : Show variables and settings.
settings :
	@echo 'SRC_RMD:' $(SRC_RMD)
	@echo 'DST_RMD:' $(DST_RMD)
	@echo 'SRC_MD:' $(SRC_MD)
	@echo 'DST_HTML:' $(DST_HTML)

## unittest : Run internal tests to ensure the validator is working correctly (for Python 2 and 3).
unittest: tools/check.py tools/validation_helpers.py tools/test_check.py
	cd tools/ && python2 test_check.py
	cd tools/ && python3 test_check.py
