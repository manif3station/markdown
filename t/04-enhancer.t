use strict;
use warnings;

use Test::More;

use lib 'lib';

use Markdown::Enhancer;

my $enhancer = Markdown::Enhancer->new;

{
    my $html = $enhancer->preprocess_for_html(<<'MARKDOWN');
| Name | Value |
| --- | --- |
| `alpha` | beta |

Use `gamma` here.
MARKDOWN

    like( $html, qr/<table>/, 'enhancer converts markdown tables into html table markup' );
    like( $html, qr/<code>alpha<\/code>/, 'enhancer renders inline code inside tables' );
    like( $html, qr/Use <code>gamma<\/code> here\./, 'enhancer renders inline code in regular text' );
    unlike( $html, qr/\|\s*Name\s*\|/, 'enhancer removes raw pipe syntax from html-preprocessed tables' );
}

{
    my $lines = $enhancer->markdown_to_pdf_lines(<<'MARKDOWN');
| Name | Value |
| --- | --- |
| `alpha` | beta |

Quote `gamma`
MARKDOWN

    ok( scalar grep { $_ eq 'Name    Value' } @{$lines}, 'enhancer produces plain table header text for pdf rendering' );
    ok( scalar grep { $_ eq 'alpha    beta' } @{$lines}, 'enhancer strips backticks from table cell text for pdf rendering' );
    ok( scalar grep { $_ eq 'Quote gamma' } @{$lines}, 'enhancer strips backticks from regular text for pdf rendering' );
    ok( !scalar grep { /\|/ } @{$lines}, 'enhancer leaves no raw pipe syntax in pdf-render lines' );
}

{
    my $lines = $enhancer->markdown_to_pdf_lines(<<'MARKDOWN');
# Heading
- bullet item

plain paragraph
MARKDOWN

    ok( scalar grep { $_ eq '# Heading' } @{$lines}, 'enhancer keeps heading markers for downstream pdf heading rendering' );
    ok( scalar grep { $_ eq '* bullet item' } @{$lines}, 'enhancer keeps bullet markers for downstream pdf list rendering' );
    ok( scalar grep { $_ eq '' } @{$lines}, 'enhancer keeps blank lines for downstream pdf spacing' );
    ok( scalar grep { $_ eq 'plain paragraph' } @{$lines}, 'enhancer keeps paragraph text for downstream pdf rendering' );
}

{
    my $html = $enhancer->preprocess_for_html(<<'MARKDOWN');
> quoted `value`

```
my $x = 1;
```
MARKDOWN

    like( $html, qr/> quoted <code>value<\/code>/, 'enhancer keeps blockquote text while fixing inline code for html preprocessing' );
    like( $html, qr/<pre><code>my \$x = 1;<\/code><\/pre>/, 'enhancer turns fenced code into pre/code html output' );
}

{
    my $lines = $enhancer->markdown_to_pdf_lines(<<'MARKDOWN');
> quoted `value`

```
my $x = 1;
```
MARKDOWN

    ok( scalar grep { $_ eq 'Quote: quoted value' } @{$lines}, 'enhancer normalizes blockquotes for pdf-render lines' );
    ok( scalar grep { $_ eq 'my $x = 1;' } @{$lines}, 'enhancer keeps fenced code content for pdf-render lines' );
}

done_testing;
