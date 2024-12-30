#** @file Moon.pm
package Doxygen::Filter::Moon;

use warnings;
use strict;
use parent qw(Doxygen::Filter);
use Log::Log4perl;
use IO::Handle;
use File::Slurp;

=head1 VERSION

Version 0.01

=cut

our $VERSION = '0.01';
$VERSION = eval $VERSION;


my $validStates = {
    'NORMAL'        => 0,
    'COMMENT'       => 1,
    'DOXYGEN'       => 2,
    'METHOD'        => 3,
    'DOXYFILE'      => 21,
    'DOXYCLASS'     => 22,
    'DOXYFUNCTION'  => 23,
    'DOXYMETHOD'    => 24,
    'DOXYCOMMENT'   => 25,
};


=head2 SUBROUTINES/METHODS

=head1 new

This function will create a Doxygen::Moon object.

=cut

sub new
{
    #** @method private new ()
    # This is the constructor and it calls _init() to initiate
    # the various variables
    #*
    my $pkg = shift;
    my $class = ref($pkg) || $pkg;

    my $self = {};
    bless ($self, $class);

    $self->{'_iDebug'}           = 1;

    my $logger = $self->GetLogger($self);

    $logger->debug("=== Entering New ===");
    $logger->info("Class : $class\n");

    # Lets send any passed in arguments to the _init method
    $self->_init(@_);
    return $self;
}

sub DESTROY
{
    #** @method private DESTROY ()
    # This is the destructor
    #*
    my $self = shift;
    $self = {};
}

sub RESETSUB
{
    my $self = shift;
    $self->{'_iOpenBrace'}          = 0;
    $self->{'_iCloseBrace'}         = 0;
    $self->{'_sCurrentMethodName'}  = undef;
    $self->{'_sCurrentMethodType'}  = undef;
    $self->{'_sCurrentMethodState'} = undef;
}

sub RESETFILE  { my $self = shift; $self->{'_aRawFileData'}   = []; $self->{'_aUncommentFileData'}   = [];   }

sub RESETCLASS
{
    my $self = shift;
    #$self->{'_sCurrentClass'}  = 'main';
    #push (@{$self->{'_hData'}->{'class'}->{'classorder'}}, 'main');
    $self->_SwitchClass('main');
}

sub RESETDOXY  { shift->{'_aDoxygenBlock'}  = [];    }

sub _init
{
    my $self = shift;
    $self->{'_sState'}          = undef;
    $self->{'_sPreviousState'}  = [];
    $self->_ChangeState('NORMAL');
    $self->{'_hData'}           = {};
    $self->RESETFILE();
    $self->RESETCLASS();
    $self->RESETSUB();
    $self->RESETDOXY();
}

sub _ChangeState
{
    #** @method private _ChangeState ($state)
    # This method will change and keep track of the various states that the state machine
    # transitions to and from. Having this information allows you to return to a previous
    # state. If you pass nothing in to this method it will restore the previous state.
    # @param state - optional string (state to change to)
    #*

    my $self = shift;
    my $state = shift;
    my $logger = $self->GetLogger($self);
    $logger->debug("=== Entering _ChangeState ===");

    if (defined $state && exists $validStates->{$state})
    {
        $logger->debug("State pased in: $state");
        unless (defined $self->{'-sState'} && $self->{'_sState'} eq $state)
        {
            # Need to push the current state to the array BEFORE we change it and only
            # if we are not currently at that state
            push (@{$self->{'_sPreviousState'}}, $self->{'_sState'});
            $self->{'_sState'} = $state;
        }
    }
    else
    {
        # If nothing is passed in, lets set the current state to the previous state.
        $logger->debug("No state passed in, lets revert to previous state");
        my $previous = pop @{$self->{'_sPreviousState'}};
        if (defined $previous)
        {
            $logger->debug("Previous state was $previous");
        }
        else
        {
            $logger->error("There is no previous state! Setting to NORMAL");
            $previous = 'NORMAL';
        }
        $self->{'_sState'} = $previous;
    }
}


sub parse {

}

# ----------------------------------------
# Private Methods
# ----------------------------------------

sub _SwitchClass
{
    my $self = shift;
    my $class = shift;

    $self->{'_sCurrentClass'} = $class;
    if (!exists $self->{'_hData'}->{'class'}->{$class})
    {
        push(@{$self->{'_hData'}->{'class'}->{'classorder'}}, $class);
        $self->{'_hData'}->{'class'}->{$class} = {
            classname                   => $class,
            inherits                    => [],
            attributeorder              => [],
            subroutineorder             => [],
        };
    }

    return $self->{'_hData'}->{'class'}->{$class};
}



1; # End of Doxygen::Moon
