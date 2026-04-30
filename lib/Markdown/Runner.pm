package Markdown::Runner;

use strict;
use warnings;

use File::Basename qw(fileparse);
use File::Spec;

sub new {
    my ( $class, %args ) = @_;
    my $self = bless {
        markdown_to_html => $args{markdown_to_html} || \&_default_markdown_to_html,
        markdown_to_pdf  => $args{markdown_to_pdf} || \&_default_markdown_to_pdf,
        html_to_markdown => $args{html_to_markdown} || \&_default_html_to_markdown,
        pdf_to_markdown  => $args{pdf_to_markdown} || \&_default_pdf_to_markdown,
        logger           => $args{logger} || sub { },
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

    if ( $source_format eq 'markdown' && $target_format eq 'html' ) {
        $self->_markdown_to_html( $from, $output_path );
    }
    elsif ( $source_format eq 'markdown' && $target_format eq 'pdf' ) {
        $self->_markdown_to_pdf( $from, $output_path );
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

    die "Choose only one of --pdf/--to-pdf or --html/--to-html\n" if $to_pdf && $to_html;

    if ( $source_format eq 'markdown' ) {
        return 'pdf'  if $to_pdf;
        return 'html' if $to_html;
        if ( defined $to && $to ne '' ) {
            my $ext = lc( ( fileparse( $to, qr/\.[^.]*/ ) )[2] || '' );
            return 'pdf'  if $ext eq '.pdf';
            return 'html' if $ext eq '.html' || $ext eq '.htm';
            die "Markdown source needs --pdf/--to-pdf, --html/--to-html, or a .pdf/.html output path\n";
        }
        die "Markdown source needs a target format\n";
    }

    die "HTML source can only convert to markdown\n" if $source_format eq 'html' && ( $to_pdf || $to_html );
    die "PDF source can only convert to markdown\n"  if $source_format eq 'pdf'  && ( $to_pdf || $to_html );

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
    my ( $self, $from, $to ) = @_;
    my $markdown = $self->_read_text($from);
    $self->_log("step=markdown_to_pdf.perl");
    $self->{markdown_to_pdf}->( $markdown, $to );
    return 1;
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
    my ($markdown) = @_;
    require Markdown::Perl;
    my $converter = Markdown::Perl->new;
    return $converter->convert($markdown);
}

sub _default_html_to_markdown {
    my ($html) = @_;
    require HTML::WikiConverter;
    my $converter = HTML::WikiConverter->new( dialect => 'Markdown' );
    return $converter->html2wiki($html);
}

sub _default_markdown_to_pdf {
    my ( $markdown, $to ) = @_;
    require PDF::API2;

    my $pdf = PDF::API2->new;
    my $page = $pdf->page;
    $page->mediabox('A4');
    my $text = $page->text;
    my $font_regular = $pdf->corefont( 'Helvetica',      -encoding => 'utf8' );
    my $font_bold    = $pdf->corefont( 'Helvetica-Bold', -encoding => 'utf8' );
    my $x = 50;
    my $y = 792 - 50;
    my $width = 595 - 100;

    for my $raw_line ( split /\n/, $markdown ) {
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
                $page = $pdf->page;
                $page->mediabox('A4');
                $text = $page->text;
                $y = 792 - 50;
            }
            $text->font( $font, $size );
            $text->translate( $x, $y );
            $text->text($segment);
            $y -= $leading;
        }

        $y -= 6 if $raw_line =~ /^\s*$/;
    }

    $pdf->saveas($to);
    return 1;
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
