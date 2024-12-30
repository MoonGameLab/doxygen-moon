
package Doxygen::Moon;


use warnings;
use strict;

=head1 NAME

Doxygen::Moon - Make Doxygen support Moonscript

=head1 VERSION

Version 0.01

=cut

our $VERSION = '0.01';

=head2 SUBROUTINES/METHODS

=head1 new

This function will create a Doxygen::Moon object.

=cut

sub new {
    my ($class, %args) = @_;
    my $self = bless \%args, $class;
    $self->_init;
    return $self;
}

sub _init {
    my $self = shift;
    $self->{mark} = '--!';
}


=head2 parse

This function will parse the given input file and return the result.

=cut

sub parse {
    my $self = shift;
    my $input = shift;

    my $in_block = 0;
    my $in_function = 0;
    my $in_fat_arrow_function = 0;
    my $block_name = q{};
    my $result = q{};

    my $mark = $self->mark;
    my $current_indent = 0;

    open FH, "<$input"
        or die "Can't open $input for reading: $!";

    foreach my $line (<FH>) {
        chomp $line;


        # include empty lines
        if ($line =~ m{^\s*$}) {
            $result .= "\n";
        }
        # skip normal comments
        next if $line =~ /^\s*--[^!]/;

        # remove end of line comments
        $line =~ s/--[^!].*//;
        # skip comparison
        next if $line =~ /==/;
        # translate to doxygen mark
        $line =~ s{$mark}{///};

        if ($line =~ m{^\s*///}) {
            $result .= "$line\n";
        }
        # function start
        elsif ($line =~ /^(\w+)\s*=\s*\(([^)]*)\)\s*->/) {
            $in_function = 1;
            $current_indent = length($1);
            $line .= q{;};
            $line =~ s/=//;
            $result .= "$line\n";
        }
         # fat arrow function start
        elsif ($line =~ /^(\w+)\s*=\s*\(([^)]*)\)\s*=>/) {
            $in_fat_arrow_function = 1;
            $current_indent = length($1);
            $line =~ s/^(\w+)\s*=\s*\(([^)]*)\)\s*=>/$1(self, $2) ->/;
            $line .= q{;};
            $result .= "$line\n";
        }
        elsif (($in_function == 1 || $in_fat_arrow_function == 1) && $line =~ /^(\s*)/ && length($1) < $current_indent) {
            # Function ends when the current indentation level is less than the function's starting level
            $in_function = 0;
            $in_fat_arrow_function = 0;
            $current_indent = 0;
        }
        # block start
        elsif (($in_function == 0 && $in_fat_arrow_function == 0) && $line =~ /^(\S+)\s*=\s*{/ && $line !~ /}/) {
            $block_name = $1;
            $in_block = 1;
        }
        # block end
        elsif (($in_function == 0 && $in_fat_arrow_function == 0) && $line =~ /^\s*}/ && $in_block == 1) {
            $block_name = q{};
            $in_block = 0;
        }
        # variables
        elsif (($in_function == 0 && $in_fat_arrow_function == 0) && ($line =~ /=/ || $line =~ /:/) && $line !~ /\(\)\s*->/) {
            $line =~ s/(?=\S)/$block_name./ if $block_name;
            $line =~ s{,?(\s*)(?=///|$)}{;$1};
            $result .= "$line\n";
        }

    }

    close FH;
    return $result;
}



=head2 mark

This function will set the mark style. The default value is "--!".

=cut

sub mark {
    my ($self, $value) = @_;
    $self->{mark} = $value if $value;
    return $self->{mark};
}



1; # End of Doxygen::Moon
