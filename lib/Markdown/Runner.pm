package Markdown::Runner;

use strict;
use warnings;

use File::Basename qw(fileparse);
use File::Spec;
use File::Temp qw(tempdir);

sub new {
    my ( $class, %args ) = @_;
    my $self = bless {
        run_command       => $args{run_command} || \&_default_run_command,
        command_available => $args{command_available} || \&_default_command_available,
        tempdir_factory   => $args{tempdir_factory} || sub { tempdir( CLEANUP => 1 ) },
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
    $self->_run_command(
        [
            'pandoc',
            '--from', 'gfm',
            '--to', 'html5',
            '--standalone',
            '--output', $to,
            $from,
        ]
    );
}

sub _html_to_markdown {
    my ( $self, $from, $to ) = @_;
    $self->_run_command(
        [
            'pandoc',
            '--from', 'html',
            '--to', 'gfm',
            '--output', $to,
            $from,
        ]
    );
}

sub _markdown_to_pdf {
    my ( $self, $from, $to ) = @_;
    my $tmpdir = $self->{tempdir_factory}->();
    my $html = File::Spec->catfile( $tmpdir, 'markdown-to-pdf.html' );
    $self->_markdown_to_html( $from, $html );

    if ( $self->{command_available}->('wkhtmltopdf') ) {
        $self->_run_command( [ 'wkhtmltopdf', $html, $to ] );
        return 1;
    }

    if ( $self->{command_available}->('weasyprint') ) {
        $self->_run_command( [ 'weasyprint', $html, $to ] );
        return 1;
    }

    die "No supported markdown-to-pdf backend found. Install wkhtmltopdf or weasyprint\n";
}

sub _pdf_to_markdown {
    my ( $self, $from, $to ) = @_;
    my $tmpdir = $self->{tempdir_factory}->();
    my $html = File::Spec->catfile( $tmpdir, 'pdf-to-markdown.html' );
    $self->_run_command( [ 'pdftohtml', '-q', '-noframes', '-s', $from, $html ] );
    $self->_html_to_markdown( $html, $to );
}

sub _run_command {
    my ( $self, $argv ) = @_;
    $self->{run_command}->($argv);
    return 1;
}

sub _default_run_command {
    my ($argv) = @_;
    my $rc = system @{$argv};
    die "Failed to run @$argv\n" if $rc != 0;
    return 1;
}

sub _default_command_available {
    my ($command) = @_;
    return 0 if !defined $command || $command eq '';
    my $rc = system( 'sh', '-c', "command -v '$command' >/dev/null 2>&1" );
    return $rc == 0 ? 1 : 0;
}

1;
