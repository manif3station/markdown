package Markdown::CLI;

use strict;
use warnings;

use Getopt::Long qw(GetOptionsFromArray);
use JSON::PP qw(encode_json);

use Markdown::Runner;

sub main {
    my (%args) = @_;
    my $argv = $args{argv} || [];
    my $logger = $args{logger} || sub { print STDERR "[markdown] $_[0]\n" };
    my %opt = (
        runner => $args{runner} || Markdown::Runner->new( logger => $logger ),
    );
    my @paper_values;

    my $ok = GetOptionsFromArray(
        $argv,
        'from=s'   => \$opt{from},
        'to:s'     => \$opt{to},
        'to-pdf'   => \$opt{to_pdf},
        'pdf'      => \$opt{pdf},
        'to-html'  => \$opt{to_html},
        'html'     => \$opt{html},
        'paper=s'  => sub { push @paper_values, $_[1]; $opt{paper} = $_[1]; },
        'A=i'      => sub { push @paper_values, 'A' . $_[1]; $opt{paper_number} = $_[1]; },
        'landscape'=> \$opt{landscape},
        'portrait' => \$opt{portrait},
    );

    if ( !$ok ) {
        print STDERR _usage();
        return 1;
    }

    if ( defined $opt{paper_number} ) {
        $opt{paper} = 'A' . $opt{paper_number};
    }

    if ( @paper_values > 1 ) {
        print STDERR "Choose only one paper size selection\n";
        return 1;
    }

    if ( @{$argv} > 2 ) {
        print STDERR "Unexpected arguments: @{$argv}\n";
        print STDERR _usage();
        return 1;
    }

    if ( !$opt{from} && @{$argv} ) {
        $opt{from} = shift @{$argv};
    }

    if ( !defined $opt{to} && @{$argv} ) {
        $opt{to} = shift @{$argv};
    }

    if ( @{$argv} ) {
        print STDERR "Unexpected arguments: @{$argv}\n";
        print STDERR _usage();
        return 1;
    }

    if ( !$opt{from} ) {
        print STDERR _usage();
        return 1;
    }

    my $result = eval {
        $opt{runner}->convert(
            from        => $opt{from},
            to          => $opt{to},
            to_pdf      => $opt{to_pdf} || $opt{pdf},
            to_html     => $opt{to_html} || $opt{html},
            paper       => $opt{paper},
            landscape   => $opt{landscape},
            portrait    => $opt{portrait},
        );
    };
    if ($@) {
        my $error = $@;
        $error =~ s/\s+\z//;
        print STDERR "$error\n";
        return 1;
    }

    print encode_json($result) . "\n";
    return 0;
}

sub _usage {
    return <<'USAGE';
Usage: dashboard markdown.convert <source> [target]
       dashboard markdown.convert --from <source> [--to <target>] [--to-pdf|--pdf|--to-html|--html] [--paper A4|B5|C7|DL|ANSI-D|-A 4] [--landscape|--portrait]

Examples:
  dashboard markdown.convert notes.md notes.pdf
  dashboard markdown.convert report.docx
  dashboard markdown.convert report.docx report.pdf
  dashboard markdown.convert scan.pdf scan.docx
  dashboard markdown.convert notes.md notes.pdf --paper A3 --landscape
  dashboard markdown.convert notes.md notes.pdf --paper ANSI-D
  dashboard markdown.convert notes.md notes.pdf --paper DL
  dashboard markdown.convert notes.md notes.pdf -A 3 --landscape
  dashboard markdown.convert notes.md notes.pdf -A 0
  dashboard markdown.convert notes.md notes.html
  dashboard markdown.convert notes.html
  dashboard markdown.convert scan.pdf
USAGE
}

1;
