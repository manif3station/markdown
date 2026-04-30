package Markdown::Enhancer;

use strict;
use warnings;

sub new {
    my ($class) = @_;
    return bless {}, $class;
}

sub markdown_to_html {
    my ( $self, $markdown ) = @_;
    require Markdown::Perl;
    my $converter = Markdown::Perl->new;
    my $enhanced = $self->preprocess_for_html($markdown);
    return $converter->convert($enhanced);
}

sub markdown_to_pdf_lines {
    my ( $self, $markdown ) = @_;
    my @lines;

    for my $block ( @{ $self->parse_blocks($markdown) } ) {
        if ( $block->{type} eq 'heading' ) {
            push @lines, '#' x $block->{level} . ' ' . $block->{text};
        }
        elsif ( $block->{type} eq 'bullet' ) {
            push @lines, '* ' . $block->{text};
        }
        elsif ( $block->{type} eq 'blockquote' ) {
            push @lines, 'Quote: ' . $block->{text};
        }
        elsif ( $block->{type} eq 'table' ) {
            push @lines, $self->_table_row_to_text($_) for @{ $block->{rows} };
        }
        elsif ( $block->{type} eq 'code' ) {
            push @lines, $_ for @{ $block->{lines} };
        }
        elsif ( $block->{type} eq 'paragraph' ) {
            push @lines, $block->{text};
        }
        elsif ( $block->{type} eq 'blank' ) {
            push @lines, '';
        }
    }

    return \@lines;
}

sub preprocess_for_html {
    my ( $self, $markdown ) = @_;
    my @output;

    for my $block ( @{ $self->parse_blocks($markdown) } ) {
        if ( $block->{type} eq 'table' ) {
            push @output, $self->_table_to_html( $block->{rows} );
        }
        elsif ( $block->{type} eq 'code' ) {
            my $body = join "\n", map { _escape_html($_) } @{ $block->{lines} };
            push @output, "<pre><code>$body</code></pre>";
        }
        elsif ( $block->{type} eq 'blank' ) {
            push @output, '';
        }
        else {
            push @output, $self->_inject_inline_code( $block->{raw} );
        }
    }

    return join "\n", @output;
}

sub parse_blocks {
    my ( $self, $markdown ) = @_;
    my @lines = split /\n/, ( defined $markdown ? $markdown : '' ), -1;
    my @blocks;
    my $i = 0;

    while ( $i <= $#lines ) {
        my $line = $lines[$i];

        if ( $line =~ /^```/ ) {
            my @code;
            $i++;
            while ( $i <= $#lines && $lines[$i] !~ /^```/ ) {
                push @code, $lines[$i];
                $i++;
            }
            $i++ if $i <= $#lines && $lines[$i] =~ /^```/;
            push @blocks, { type => 'code', lines => \@code };
            next;
        }

        if ( $self->_is_table_start( \@lines, $i ) ) {
            my ( $rows, $next ) = $self->_collect_table_rows( \@lines, $i );
            push @blocks, { type => 'table', rows => $rows };
            $i = $next;
            next;
        }

        if ( $line =~ /^\s*$/ ) {
            push @blocks, { type => 'blank', raw => '' };
            $i++;
            next;
        }

        if ( $line =~ /^(#{1,6})\s+(.*)$/ ) {
            push @blocks, {
                type  => 'heading',
                level => length($1),
                text  => $self->_plain_inline($2),
                raw   => $line,
            };
            $i++;
            next;
        }

        if ( $line =~ /^[-*]\s+(.*)$/ ) {
            push @blocks, {
                type => 'bullet',
                text => $self->_plain_inline($1),
                raw  => $line,
            };
            $i++;
            next;
        }

        if ( $line =~ /^>\s?(.*)$/ ) {
            push @blocks, {
                type => 'blockquote',
                text => $self->_plain_inline($1),
                raw  => $line,
            };
            $i++;
            next;
        }

        my @paragraph = ($line);
        $i++;
        while ( $i <= $#lines ) {
            last if $lines[$i] =~ /^\s*$/;
            last if $lines[$i] =~ /^```/;
            last if $self->_is_table_start( \@lines, $i );
            last if $lines[$i] =~ /^(#{1,6})\s+/;
            last if $lines[$i] =~ /^[-*]\s+/;
            last if $lines[$i] =~ /^>\s?/;
            push @paragraph, $lines[$i];
            $i++;
        }

        my $text = join ' ', map { s/^\s+|\s+$//gr } @paragraph;
        push @blocks, {
            type => 'paragraph',
            text => $self->_plain_inline($text),
            raw  => $text,
        };
    }

    return \@blocks;
}

sub _is_table_start {
    my ( $self, $lines, $index ) = @_;
    return 0 if $index + 1 > $#$lines;
    return 0 if !$self->_looks_like_table_row( $lines->[$index] );
    return 0 if !$self->_looks_like_table_separator( $lines->[ $index + 1 ] );
    return 1;
}

sub _collect_table_rows {
    my ( $self, $lines, $index ) = @_;
    my @rows;
    push @rows, $self->_split_table_row( $lines->[$index] );
    $index += 2;

    while ( $index <= $#$lines && $self->_looks_like_table_row( $lines->[$index] ) ) {
        push @rows, $self->_split_table_row( $lines->[$index] );
        $index++;
    }

    return ( \@rows, $index );
}

sub _looks_like_table_row {
    my ( $self, $line ) = @_;
    return 0 if !defined $line;
    return $line =~ /^\s*\|?.+\|.+\|?\s*$/ ? 1 : 0;
}

sub _looks_like_table_separator {
    my ( $self, $line ) = @_;
    return 0 if !defined $line;
    return $line =~ /^\s*\|?(?:\s*:?-{3,}:?\s*\|)+\s*:?-{3,}:?\s*\|?\s*$/ ? 1 : 0;
}

sub _split_table_row {
    my ( $self, $line ) = @_;
    $line =~ s/^\s*\|//;
    $line =~ s/\|\s*$//;
    my @cells = map { s/^\s+|\s+$//gr } split /\|/, $line, -1;
    return \@cells;
}

sub _table_to_html {
    my ( $self, $rows ) = @_;
    my $header = shift @{$rows};
    my @parts;
    push @parts, '<table border="1">';
    push @parts, '<thead><tr>' . join( '', map { '<th>' . $self->_render_inline_html($_) . '</th>' } @{$header} ) . '</tr></thead>';
    push @parts, '<tbody>';
    for my $row ( @{$rows} ) {
        push @parts, '<tr>' . join( '', map { '<td>' . $self->_render_inline_html($_) . '</td>' } @{$row} ) . '</tr>';
    }
    push @parts, '</tbody>';
    push @parts, '</table>';
    return join '', @parts;
}

sub _table_row_to_text {
    my ( $self, $row ) = @_;
    return join '    ', map { $self->_plain_inline($_) } @{$row};
}

sub _inject_inline_code {
    my ( $self, $text ) = @_;
    my @parts = split /(`[^`]+`)/, ( defined $text ? $text : '' );
    for my $part (@parts) {
        next if !defined $part || $part eq '';
        if ( $part =~ /^`([^`]+)`$/ ) {
            $part = '<code>' . _escape_html($1) . '</code>';
            next;
        }
    }
    return join '', @parts;
}

sub _render_inline_html {
    my ( $self, $text ) = @_;
    my @parts = split /(`[^`]+`)/, ( defined $text ? $text : '' );
    for my $part (@parts) {
        next if !defined $part;
        if ( $part =~ /^`([^`]+)`$/ ) {
            $part = '<code>' . _escape_html($1) . '</code>';
        }
        else {
            $part = _escape_html($part);
        }
    }
    return join '', @parts;
}

sub _plain_inline {
    my ( $self, $text ) = @_;
    $text = '' if !defined $text;
    $text =~ s/`([^`]+)`/$1/g;
    return $text;
}

sub _escape_html {
    my ($text) = @_;
    $text = '' if !defined $text;
    $text =~ s/&/&amp;/g;
    $text =~ s/</&lt;/g;
    $text =~ s/>/&gt;/g;
    return $text;
}

1;
