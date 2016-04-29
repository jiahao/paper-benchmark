MAIN=main

pdf:
	latexmk -pdf $(MAIN) -auxdir=output -outdir=output

travis:
	#Old latexmk doesn't understand auxdir and outdir options
	latexmk -pdf -pdflatex='pdflatex %S %O -interaction=nonstopmode -halt-on-error' $(MAIN)

arxiv: pdf
	mkdir -p arxiv
	cp *.pdf output/*.bbl paper.tex *.cls *.bst arxiv
	#Test build
	cd arxiv && latexmk -pdf $(MAIN) -auxdir=crap -outdir=crap && rm -rf crap
	cd arxiv && zip arxiv.zip *

clean:
	rm -rvf *.bbl *.blg *.aux *.fls *.fdb_latexmk *.log *.out *.toc $(MAIN).pdf aux output arxiv

