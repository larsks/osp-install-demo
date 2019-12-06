STYLE = revealjs

%.html: %.md
	pandoc --slide-level=2 -t $(STYLE) -s $< -o $@

all: slides.html

clean:
	rm -f slides.html
