{
  description = "Nix to various Resumé templates found online.";

  inputs = {
    nixpkgs.url = "github:nixos/nixpkgs?ref=nixos-unstable";
    pandocTemplates = {
      url = "github:jgm/pandoc-templates";
      flake = false;
    };
    moderncv= {
      url = "github:moderncv/moderncv";
      flake = false;
    };
    business-card = {
      url = "github:opieters/business-card";
      flake = false;
    };
    invoice = {
      url = "github:mrzool/invoice-boilerplate";
      flake = false;
    };
  };

  outputs = { self, nixpkgs, ... }@inputs:
    let
      system = "x86_64-linux";
      pkgs = nixpkgs.legacyPackages.${system};
    in
  {
    yamlMetadata = pkgs.writeTextFile {
      name = "header.yaml";
      text = pkgs.lib.generators.toJSON {} (import ./header.nix);
      destination = "/header.yaml";
    };

    pandocTemplates = pkgs.stdenvNoCC.mkDerivation {
      name = "pandocTemplates";
      src = inputs.pandocTemplates;
      buildPhase = ''
        mkdir -p $out/templates/pandoc
        cp $src/default.* $out/templates/pandoc/
      '';
    };

    moderncv = pkgs.stdenvNoCC.mkDerivation {
      name = "moderncv";
      src = inputs.moderncv;
      passthru = {
        pname = "moderncv";
        tlType = "run";
      };
      buildPhase = ''
        mkdir -p $out/tex/latex/moderncv/
        cp -r $src/* $out/tex/latex/moderncv/
      '';
    };

    moderncvTemplates = pkgs.stdenvNoCC.mkDerivation {
      name = "moderncvTemplates";
      src = inputs.moderncv;
      buildPhase = ''
        mkdir -p $out/templates/moderncv
        mkdir -p $out/manual
        cp $src/template.tex $out/templates/moderncv/template.tex
        cp $src/manual/moderncv_userguide.pdf $out/manual/
      '';
    };

    invoiceTemplate = pkgs.stdenvNoCC.mkDerivation {
      name = "invoiceTemplate";
      src = inputs.invoice;
      dontUnpack = true;
      buildPhase = ''
        mkdir -p $out/templates/invoice
        cp $src/template.tex $out/templates/invoice/template.tex
        cp $src/details.yml $out/templates/invoice/details.yml
      '';
    };

    business-cardTemplates = pkgs.stdenvNoCC.mkDerivation {
      name = "business-cardTemplates";
      src = inputs.business-card;
      buildPhase = ''
        mkdir -p $out/templates/business-card
        cp $src/src/front.tex $out/templates/business-card/front.tex
        cp $src/src/back.tex $out/templates/business-card/back.tex
      '';
    };

    buildInvoice = pkgs.stdenvNoCC.mkDerivation {
      name = "buildInvoice";
      src = ./.;
      buildInputs = [
        pkgs.pandoc
        self.LaTeX
      ];
      buildPhase = ''
        export HOME=$(mktemp -d)
        cp $src/templates/invoice/template.tex ./template.tex
        cp $src/invoice.md ./invoice.md

        pandoc ./invoice.md \
            --from=markdown --to=pdf \
            --template ./template.tex \
            --pdf-engine xelatex \
            --metadata-file=${self.yamlMetadata}/header.yaml \
            -V date=$(${pkgs.coreutils-full}/bin/date +%Y%m%d) \
            -V logo=logo.png \
            -o ./invoice.pdf
      '';
      installPhase = ''
        mkdir -p $out/invoice
        cp ./*.pdf $out/invoice/
      '';
    };

    LaTeX = pkgs.texlive.combine {
      scheme-small = pkgs.texlive.scheme-small // {
        pkgs = pkgs.lib.filter
          (x: (x.pname != "moderncv"))
          pkgs.texlive.scheme-small.pkgs;
      };
      moderncv = { pkgs = [ self.moderncv ]; };
      inherit (pkgs.texlive)
        latex-bin
        fontawesome5 # Font Awesome 5 with LaTeX support
        academicons # Font containing high quality icons of online academic profiles
        multirow # Create tabular cells spanning multiple rows
        qrcode # Generate QR codes in LaTeX
        tikzmark # Use TikZ's method of remembering a position on a page
        arydshln # Draw dash-lines in array/tabular
        xcolor # Driver-independent color extensions for LaTeX and pdfLaTeX
        parskip # Layout with zero parindent, non-zero parskip
        fontspec # Advanced font selection in XeLaTeX and LuaLaTeX
        fp # Fixed point arithmetic
        footmisc # A range of footnote options
        xunicode # Generate Unicode characters from accented glyphs
        xltxtra # "Extras" for LaTeX users of XeTeX
        spreadtab # Spreadsheet features for LaTeX tabular environments
        xstring # String manipulation for (La)TeX
        geometry # Flexible and complete interface to document dimensions
        ragged2e # Alternative versions of "ragged"-type commands
        wallpaper # Easy addition of wallpapers (background images) to LaTeX documents, including tiling
        titlesec # Select alternative section titles
        ehhline # Extend the hhline command
        enumitem # Control layout of itemize, enumerate, description
        hyperref # Extensive support for hypertext in LaTeX
        polyglossia # An alternative to babel for XeLaTeX and LuaLaTeX
        greek-fontenc # LICR macros and encoding definition files for Greek
        fonttable # Print font tables from a LaTeX document
        inter # The inter font face with support for LaTeX, XeLaTeX, and LuaLaTeX
      ;
    };

    buildResume = pkgs.stdenvNoCC.mkDerivation {
      name = "resume";
      src = ./.;
      buildInputs = with pkgs; [
        pandoc
        typst
        self.LaTeX
      ];
      buildPhase = ''
        export HOME=$(mktemp -d)
        cp $src/vitae.csl ./
        cp $src/vitae.bib ./
        cp $src/myself.jpg ./

        function pandocModerncv() {
          pandoc $src/resumeHeadless.md \
            --from=markdown --to=pdf \
            --template $src/templates/moderncv.tex \
            --pdf-engine xelatex \
            --metadata-file=${self.yamlMetadata}/header.yaml \
            -V moderncvstyle=$1 \
            -V date=$(${pkgs.coreutils-full}/bin/date +%Y-%m-%d) \
            -V picture=myself.jpg \
            -o ./moderncv_$(echo $1).pdf
        }

        pandocModerncv casual
        pandocModerncv classic
        pandocModerncv banking
        # pandocModerncv oldstyle
        pandocModerncv fancy
        pandocModerncv contemporary

        pandoc $src/resumeHeadless.md \
          --from=markdown --to=pdf \
          --template ${self.pandocTemplates}/templates/pandoc/default.latex \
          --pdf-engine xelatex \
          -V date=$(${pkgs.coreutils-full}/bin/date +%Y-%m-%d) \
          -V picture=myself.jpg \
          -o ./defaultPandocLatex.pdf

        pandoc $src/resumeHeadless.md \
          --from=markdown --to=typst \
          --template=$src/templates/resume.typst \
          --metadata-file=${self.yamlMetadata}/header.yaml \
          --bibliography=vitae.bib --citeproc \
          --csl=vitae.csl \
          -V date=$(${pkgs.coreutils-full}/bin/date +%Y-%m-%d) \
          -V picture=myself.jpg \
          -o ./resume.typst
        typst compile resume.typst typst.pdf
      '';
      installPhase = ''
        mkdir -p $out/resume
        cp *.typst $out/
        cp *.pdf $out/resume
      '';
    };

    buildBusinessCard = pkgs.stdenvNoCC.mkDerivation {
      name = "business-card";
      src = ./.;
      buildInputs = with pkgs; [
        pandoc
        self.LaTeX
      ];
      buildPhase = ''
        export HOME=$(mktemp -d)

        cp $src/business-card.md ./
        cp $src/myself.jpg ./
        cp $src/templates/business-card/front.tex ./
        cp $src/templates/business-card/back.tex ./
        cp $src/assets/nixcamp.png ./logo.png

        function pandocBusinesscard() {
          pandoc $src/templates/business-card/front.tex \
            --from=markdown --to=pdf \
            --template ./$(echo $1).tex \
            --pdf-engine xelatex \
            --metadata-file=${self.yamlMetadata}/header.yaml \
            -V date=$(${pkgs.coreutils-full}/bin/date +%Y-%m-%d) \
            -V logo=logo.png \
            -o ./$(echo $1).pdf
        }

        pandocBusinesscard front
        pandocBusinesscard back
      '';

      installPhase = ''
        mkdir -p $out/business-card
        cp *.pdf $out/business-card
      '';
    };

    packages.x86_64-linux.default = pkgs.symlinkJoin {
      name = "resumeBundle";
      paths = [
        self.pandocTemplates
        self.buildResume
        self.buildBusinessCard
        self.buildInvoice
        self.yamlMetadata
        self.moderncvTemplates
        self.business-cardTemplates
        self.invoiceTemplate
      ];
      postBuild = "echo links added";
    };

    devShells.x86_64-linux.default = pkgs.mkShell {
      buildInputs = [
        self.LaTeX
        pkgs.pandoc
      ];
    };
  };
}
