package Markdown::Runner;

use strict;
use warnings;

use File::Basename qw(fileparse);
use File::Spec;

use Markdown::Enhancer;

sub new {
    my ( $class, %args ) = @_;
    my $enhancer = $args{enhancer} || Markdown::Enhancer->new;
    my $self = bless {
        markdown_to_html => $args{markdown_to_html} || sub { return _default_markdown_to_html( $_[0], $enhancer ); },
        markdown_to_pdf  => $args{markdown_to_pdf}  || sub { return _default_markdown_to_pdf( $_[0], $_[1], $_[2], $enhancer ); },
        html_to_markdown => $args{html_to_markdown} || \&_default_html_to_markdown,
        pdf_to_markdown  => $args{pdf_to_markdown} || \&_default_pdf_to_markdown,
        logger           => $args{logger} || sub { },
        enhancer         => $enhancer,
    }, $class;
    return $self;
}

sub convert {
    my ( $self, %args ) = @_;
    my $from = $args{from} || die "Missing --from\n";
    die "Source file not found: $from\n" if !-f $from;

    my $source_format = $self->_detect_source_format($from);
    my $target_format = $self->_target_format_for(
        source_format => $source_format,
        to            => $args{to},
        to_pdf        => $args{to_pdf},
        to_html       => $args{to_html},
        paper         => $args{paper},
        landscape     => $args{landscape},
        portrait      => $args{portrait},
    );
    my $output_path = $self->_output_path(
        from          => $from,
        to            => $args{to},
        target_format => $target_format,
    );

    $self->_log("source=$from");
    $self->_log("source_format=$source_format");
    $self->_log("target_format=$target_format");
    $self->_log("output=$output_path");
    if ( $target_format eq 'pdf' ) {
        my $layout = $self->_pdf_layout(
            paper     => $args{paper},
            landscape => $args{landscape},
            portrait  => $args{portrait},
        );
        $self->_log( 'paper=' . $layout->{paper} );
        $self->_log( 'orientation=' . $layout->{orientation} );
    }

    if ( $source_format eq 'markdown' && $target_format eq 'html' ) {
        $self->_markdown_to_html( $from, $output_path );
    }
    elsif ( $source_format eq 'markdown' && $target_format eq 'pdf' ) {
        $self->_markdown_to_pdf(
            $from,
            $output_path,
            $self->_pdf_layout(
                paper     => $args{paper},
                landscape => $args{landscape},
                portrait  => $args{portrait},
            )
        );
    }
    elsif ( $source_format eq 'html' && $target_format eq 'markdown' ) {
        $self->_html_to_markdown( $from, $output_path );
    }
    elsif ( $source_format eq 'pdf' && $target_format eq 'markdown' ) {
        $self->_pdf_to_markdown( $from, $output_path );
    }
    else {
        die "Unsupported conversion route: $source_format -> $target_format\n";
    }

    return {
        from          => $from,
        to            => $output_path,
        source_format => $source_format,
        target_format => $target_format,
        ( $target_format eq 'pdf'
            ? (
                paper       => $self->_pdf_layout(
                    paper     => $args{paper},
                    landscape => $args{landscape},
                    portrait  => $args{portrait},
                )->{paper},
                orientation => $self->_pdf_layout(
                    paper     => $args{paper},
                    landscape => $args{landscape},
                    portrait  => $args{portrait},
                )->{orientation},
              )
            : () ),
    };
}

sub _detect_source_format {
    my ( $self, $path ) = @_;
    my ( undef, undef, $suffix ) = fileparse( $path, qr/\.[^.]*/ );
    $suffix = lc( $suffix || '' );
    return 'markdown' if $suffix eq '.md' || $suffix eq '.markdown';
    return 'html'     if $suffix eq '.html' || $suffix eq '.htm';
    return 'pdf'      if $suffix eq '.pdf';
    die "Unsupported source extension: $suffix\n";
}

sub _target_format_for {
    my ( $self, %args ) = @_;
    my $source_format = $args{source_format};
    my $to            = $args{to};
    my $to_pdf        = $args{to_pdf}  ? 1 : 0;
    my $to_html       = $args{to_html} ? 1 : 0;
    my $paper         = $args{paper};
    my $landscape     = $args{landscape} ? 1 : 0;
    my $portrait      = $args{portrait}  ? 1 : 0;

    die "Choose only one of --pdf/--to-pdf or --html/--to-html\n" if $to_pdf && $to_html;
    die "Choose only one of --landscape or --portrait\n" if $landscape && $portrait;

    if ( $source_format eq 'markdown' ) {
        if ( !$to_pdf && !$to_html && defined $to && $to ne '' ) {
            my $ext = lc( ( fileparse( $to, qr/\.[^.]*/ ) )[2] || '' );
            if ( $ext eq '.pdf' ) {
                _validate_pdf_layout( paper => $paper, landscape => $landscape, portrait => $portrait );
            }
        }
        return 'pdf'  if $to_pdf;
        return 'html' if $to_html;
        if ( defined $to && $to ne '' ) {
            my $ext = lc( ( fileparse( $to, qr/\.[^.]*/ ) )[2] || '' );
            _validate_pdf_layout( paper => $paper, landscape => $landscape, portrait => $portrait ) if $ext eq '.pdf';
            die "PDF layout flags are only valid for PDF output\n"
              if ( ( defined $paper && $paper ne '' ) || $landscape || $portrait ) && $ext ne '.pdf';
            return 'pdf'  if $ext eq '.pdf';
            return 'html' if $ext eq '.html' || $ext eq '.htm';
            die "Markdown source needs --pdf/--to-pdf, --html/--to-html, or a .pdf/.html output path\n";
        }
        die "PDF layout flags are only valid for PDF output\n"
          if ( defined $paper && $paper ne '' ) || $landscape || $portrait;
        die "Markdown source needs a target format\n";
    }

    die "HTML source can only convert to markdown\n" if $source_format eq 'html' && ( $to_pdf || $to_html );
    die "PDF source can only convert to markdown\n"  if $source_format eq 'pdf'  && ( $to_pdf || $to_html );
    die "PDF layout flags are only valid for PDF output\n"
      if ( defined $paper && $paper ne '' ) || $landscape || $portrait;

    if ( defined $to && $to ne '' ) {
        my $ext = lc( ( fileparse( $to, qr/\.[^.]*/ ) )[2] || '' );
        die "Only markdown output is supported for $source_format input\n"
          if $ext ne '' && $ext ne '.md' && $ext ne '.markdown';
    }

    return 'markdown';
}

sub _output_path {
    my ( $self, %args ) = @_;
    my $from          = $args{from};
    my $to            = $args{to};
    my $target_format = $args{target_format};
    my %suffix_for = (
        markdown => '.md',
        html     => '.html',
        pdf      => '.pdf',
    );
    my $suffix = $suffix_for{$target_format} || die "Missing target suffix for $target_format\n";

    if ( defined $to && $to ne '' ) {
        return $self->_with_extension( $to, $target_format, $suffix );
    }

    my ( $name, $dir ) = fileparse( $from, qr/\.[^.]*/ );
    return File::Spec->catfile( $dir, $name . $suffix );
}

sub _with_extension {
    my ( $self, $path, $target_format, $suffix ) = @_;
    my $lower = lc($path);
    return $path if $lower =~ /\Q$suffix\E\z/i;
    return $path if $target_format eq 'markdown' && $lower =~ /\.markdown\z/;
    return $path if $target_format eq 'html'     && $lower =~ /\.htm\z/;
    $path =~ s/\.[^.]+\z// if $path =~ /\/?[^\/]+\.[^.]+\z/;
    return $path . $suffix;
}

sub _markdown_to_html {
    my ( $self, $from, $to ) = @_;
    $self->_log("step=markdown_to_html.perl");
    my $markdown = $self->_read_text($from);
    my $html = $self->{markdown_to_html}->($markdown);
    $self->_write_text( $to, $html );
    return 1;
}

sub _html_to_markdown {
    my ( $self, $from, $to ) = @_;
    $self->_log("step=html_to_markdown.perl");
    my $html = $self->_read_text($from);
    my $markdown = $self->{html_to_markdown}->($html);
    $self->_write_text( $to, $markdown );
    return 1;
}

sub _markdown_to_pdf {
    my ( $self, $from, $to, $layout ) = @_;
    my $markdown = $self->_read_text($from);
    $self->_log("step=markdown_to_pdf.perl");
    $self->{markdown_to_pdf}->( $markdown, $to, $layout );
    return 1;
}

sub _pdf_layout {
    my ( $self, %args ) = @_;
    return _validate_pdf_layout(%args);
}

sub _pdf_to_markdown {
    my ( $self, $from, $to ) = @_;
    $self->_log("step=pdf_to_markdown.perl");
    my $markdown = $self->{pdf_to_markdown}->($from);
    $self->_write_text( $to, $markdown );
    return 1;
}

sub _read_text {
    my ( $self, $path ) = @_;
    open my $fh, '<:raw', $path or die "Unable to read $path: $!\n";
    local $/;
    my $content = <$fh>;
    close $fh or die "Unable to close $path: $!\n";
    return $content;
}

sub _write_text {
    my ( $self, $path, $content ) = @_;
    open my $fh, '>:raw', $path or die "Unable to write $path: $!\n";
    print {$fh} $content;
    close $fh or die "Unable to close $path: $!\n";
    return 1;
}

sub _log {
    my ( $self, $message ) = @_;
    $self->{logger}->($message);
    return 1;
}

sub _default_markdown_to_html {
    my ( $markdown, $enhancer ) = @_;
    $enhancer ||= Markdown::Enhancer->new;
    return $enhancer->markdown_to_html($markdown);
}

sub _default_html_to_markdown {
    my ($html) = @_;
    require HTML::WikiConverter;
    my $converter = HTML::WikiConverter->new( dialect => 'Markdown' );
    return $converter->html2wiki($html);
}

sub _default_markdown_to_pdf {
    my ( $markdown, $to, $layout, $enhancer ) = @_;
    require PDF::API2;
    $enhancer ||= Markdown::Enhancer->new;
    $layout ||= _validate_pdf_layout();

    my $pdf = PDF::API2->new;
    my $font_regular = $pdf->corefont( 'Helvetica',      -encoding => 'utf8' );
    my $font_bold    = $pdf->corefont( 'Helvetica-Bold', -encoding => 'utf8' );
    my $x = 50;
    my ( $page, $text, $gfx, $y, $page_width, $page_height ) = _new_pdf_page( $pdf, $layout );
    my $width = $page_width - 100;

    for my $block ( @{ $enhancer->parse_blocks($markdown) } ) {
        if ( $block->{type} eq 'table' ) {
            ( $page, $text, $gfx, $y, $page_width, $page_height ) = _render_pdf_table(
                pdf          => $pdf,
                page         => $page,
                text         => $text,
                gfx          => $gfx,
                y            => $y,
                rows         => $block->{rows},
                x            => $x,
                width        => $width,
                font_regular => $font_regular,
                font_bold    => $font_bold,
                layout       => $layout,
            );
            $width = $page_width - 100;
            next;
        }

        my @lines = _pdf_lines_for_block($block);
        for my $raw_line (@lines) {
            my $line = $raw_line;
            my $font = $font_regular;
            my $size = 12;
            my $leading = 16;

            if ( $line =~ s/^###\s+// ) {
                $font = $font_bold;
                $size = 14;
                $leading = 20;
            }
            elsif ( $line =~ s/^##\s+// ) {
                $font = $font_bold;
                $size = 18;
                $leading = 24;
            }
            elsif ( $line =~ s/^#\s+// ) {
                $font = $font_bold;
                $size = 24;
                $leading = 30;
            }
            elsif ( $line =~ s/^[-*]\s+/* / ) {
                $size = 12;
            }

            my @wrapped = _wrap_text( $font, $size, $line, $width );
            @wrapped = ('') if !@wrapped;

            for my $segment (@wrapped) {
                if ( $y < 50 ) {
                    ( $page, $text, $gfx, $y, $page_width, $page_height ) = _new_pdf_page( $pdf, $layout );
                    $width = $page_width - 100;
                }
                $text->font( $font, $size );
                $text->translate( $x, $y );
                $text->text($segment);
                $y -= $leading;
            }

            $y -= 6 if $raw_line =~ /^\s*$/;
        }
    }

    $pdf->saveas($to);
    return 1;
}

sub _new_pdf_page {
    my ( $pdf, $layout ) = @_;
    $layout ||= _validate_pdf_layout();
    $layout->{paper}       ||= 'A4';
    $layout->{orientation} ||= 'portrait';
    my ( $width, $height ) = _paper_dimensions( $layout->{paper} );
    ( $width, $height ) = ( $height, $width ) if $layout->{orientation} eq 'landscape';
    my $page = $pdf->page;
    $page->mediabox( 0, 0, $width, $height );
    my $text = $page->text;
    my $gfx  = $page->gfx;
    my $y    = $height - 50;
    return ( $page, $text, $gfx, $y, $width, $height );
}

sub _pdf_lines_for_block {
    my ($block) = @_;
    return ( '#' x $block->{level} . ' ' . $block->{text} ) if $block->{type} eq 'heading';
    return ( '* ' . $block->{text} ) if $block->{type} eq 'bullet';
    return ( 'Quote: ' . $block->{text} ) if $block->{type} eq 'blockquote';
    return @{ $block->{lines} } if $block->{type} eq 'code';
    return ( $block->{text} ) if $block->{type} eq 'paragraph';
    return ('') if $block->{type} eq 'blank';
    return;
}

sub _render_pdf_table {
    my (%args) = @_;
    my $pdf          = $args{pdf};
    my $page         = $args{page};
    my $text         = $args{text};
    my $gfx          = $args{gfx};
    my $y            = $args{y};
    my $rows         = $args{rows} || [];
    my $x            = $args{x};
    my $width        = $args{width};
    my $font_regular = $args{font_regular};
    my $font_bold    = $args{font_bold};
    my $layout       = $args{layout} || _validate_pdf_layout();
    $layout->{paper}       ||= 'A4';
    $layout->{orientation} ||= 'portrait';
    my $padding      = 6;
    my $size         = 11;
    my $leading      = 14;
    my $columns      = scalar @{ $rows->[0] || [] } || 1;
    my $cell_width   = $width / $columns;

    for my $row_index ( 0 .. $#$rows ) {
        my $row  = $rows->[$row_index];
        my $font = $row_index == 0 ? $font_bold : $font_regular;
        my @cell_lines;
        my $max_lines = 1;

        for my $cell (@{$row}) {
            my $plain_cell = Markdown::Enhancer->_plain_inline($cell);
            my @wrapped = _wrap_text( $font, $size, $plain_cell, $cell_width - ( $padding * 2 ) );
            @wrapped = ('') if !@wrapped;
            push @cell_lines, \@wrapped;
            $max_lines = @wrapped if @wrapped > $max_lines;
        }

        my $row_height = ( $max_lines * $leading ) + ( $padding * 2 );
        if ( $y - $row_height < 50 ) {
            my ( $new_page, $new_text, $new_gfx, $new_y, $new_width, $new_height ) = _new_pdf_page( $pdf, $layout );
            ( $page, $text, $gfx, $y ) = ( $new_page, $new_text, $new_gfx, $new_y );
            if ( !defined $new_width ) {
                my ( $fallback_width, $fallback_height ) = _paper_dimensions( $layout->{paper} );
                ( $fallback_width, $fallback_height ) = ( $fallback_height, $fallback_width )
                  if $layout->{orientation} eq 'landscape';
                $new_width = $fallback_width;
            }
            $width      = $new_width - 100;
            $cell_width = $width / $columns;
        }

        for my $col_index ( 0 .. $#$row ) {
            my $cell_x = $x + ( $col_index * $cell_width );
            $gfx->rect( $cell_x, $y - $row_height, $cell_width, $row_height );
            $gfx->stroke;
            my $line_y = $y - $padding - $size;
            for my $segment ( @{ $cell_lines[$col_index] } ) {
                $text->font( $font, $size );
                $text->translate( $cell_x + $padding, $line_y );
                $text->text($segment);
                $line_y -= $leading;
            }
        }

        $y -= $row_height;
    }

    $y -= 8;
    my ( $page_width, $page_height ) = _paper_dimensions( $layout->{paper} );
    ( $page_width, $page_height ) = ( $page_height, $page_width ) if $layout->{orientation} eq 'landscape';
    return ( $page, $text, $gfx, $y, $page_width, $page_height );
}

sub _validate_pdf_layout {
    my (%args) = @_;
    my $paper = uc( $args{paper} || 'A4' );
    my %valid = map { $_ => 1 } qw(A1 A2 A3 A4);
    die "Unsupported paper size: $paper\n" if !$valid{$paper};
    die "Choose only one of --landscape or --portrait\n" if ( $args{landscape} && $args{portrait} );
    my $orientation = $args{landscape} ? 'landscape' : 'portrait';
    return {
        paper       => $paper,
        orientation => $orientation,
    };
}

sub _paper_dimensions {
    my ($paper) = @_;
    $paper = 'A4' if !defined $paper || $paper eq '';
    my %size = (
        A1 => [ 1684, 2384 ],
        A2 => [ 1191, 1684 ],
        A3 => [ 842, 1191 ],
        A4 => [ 595, 842 ],
    );
    my $dims = $size{$paper} || die "Unsupported paper size: $paper\n";
    return @{$dims};
}

sub _wrap_text {
    my ( $font, $size, $line, $width ) = @_;
    return ('') if !defined $line || $line eq '';
    my @words = split /\s+/, $line;
    my @lines;
    my $current = shift @words;
    $current = '' if !defined $current;

    for my $word (@words) {
        my $candidate = length $current ? "$current $word" : $word;
        my $candidate_width = ( $font->width($candidate) / 1000 ) * $size;
        if ( $candidate_width <= $width ) {
            $current = $candidate;
            next;
        }
        push @lines, $current;
        $current = $word;
    }

    push @lines, $current if defined $current;
    return @lines;
}

sub _default_pdf_to_markdown {
    my ($from) = @_;
    require CAM::PDF;
    my $pdf = CAM::PDF->new($from);
    my $pages = $pdf->numPages();
    my @chunks;
    for my $page ( 1 .. $pages ) {
        my $text = $pdf->getPageText($page);
        $text = '' if !defined $text;
        $text =~ s/\r\n?/\n/g;
        $text =~ s/[ \t]+\n/\n/g;
        $text =~ s/\n{3,}/\n\n/g;
        $text =~ s/\A\s+|\s+\z//g;
        push @chunks, $text if length $text;
    }
    my $markdown = join "\n\n", @chunks;
    $markdown .= "\n" if length $markdown;
    return $markdown;
}

1;
