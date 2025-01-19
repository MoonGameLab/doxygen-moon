#** @file Moon.pm
# @verbatim
#####################################################################
# This program is not guaranteed to work at all, and by using this  #
# program you release the author of any and all liability.          #
#                                                                   #
# You may use this code as long as you are in compliance with the   #
# license (see the LICENSE file) and this notice, disclaimer and    #
# comment box remain intact and unchanged.                          #
#                                                                   #
# Package:     Doxygen                                              #
# Class:       Filter                                               #
# Description: Methods for prefiltering Moonscript code for Doxygen #
#                                                                   #
# Written by:  Tourahi Amine                                        #
# Created:     2025-01-19                                           #
#####################################################################
# @endverbatim
#
# @copy 2025, Tourahi Amine (tourahi.amine@gmail.com)
#*
package Doxygen::Filter;

use 5.8.8;
use strict;
use warnings;
use Log::Log4perl;

our $VERSION     = '0.1';
$VERSION = eval $VERSION;


sub GetLogger
{
    #** @method public GetLogger ($object)
    # This method is a helper method to get the Log4perl logger object and make sure
    # it knows from which class it was called regardless of where it actually lives.
    #*
    my $self = shift;
    my $object = shift;
    my $package = ref($object);
    my @data = caller(1);
    my $caller = (split "::", $data[3])[-1];
    my $sLoggerName = $package . "::" . $caller;
    print "+++ DEBUGGER +++ $sLoggerName\n" if ($self->{'_iDebug'} == 1);

    return Log::Log4perl->get_logger("$sLoggerName");
}


return 1;
