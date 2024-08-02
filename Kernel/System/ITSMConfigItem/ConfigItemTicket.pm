# --
# OTOBO is a web-based ticketing system for service organisations.
# --
# Copyright (C) 2001-2020 OTRS AG, https://otrs.com/
# Copyright (C) 2019-2024 Rother OSS GmbH, https://otobo.de/
# --
# This program is free software: you can redistribute it and/or modify it under
# the terms of the GNU General Public License as published by the Free Software
# Foundation, either version 3 of the License, or (at your option) any later version.
# This program is distributed in the hope that it will be useful, but WITHOUT
# ANY WARRANTY; without even the implied warranty of MERCHANTABILITY or FITNESS
# FOR A PARTICULAR PURPOSE. See the GNU General Public License for more details.
# You should have received a copy of the GNU General Public License
# along with this program. If not, see <https://www.gnu.org/licenses/>.
# --

package Kernel::System::ITSMConfigItem::ConfigItemTicket;

use v5.24;
use strict;
use warnings;
use namespace::autoclean;
use utf8;

use parent qw(
    Kernel::System::EventHandler
    Kernel::System::ITSMConfigItem
    Kernel::System::ITSMConfigItem::ConfigItemACL
    Kernel::System::ITSMConfigItem::ConfigItemSearch
    Kernel::System::ITSMConfigItem::Definition
    Kernel::System::ITSMConfigItem::History
    Kernel::System::ITSMConfigItem::Link
    Kernel::System::ITSMConfigItem::Number
    Kernel::System::ITSMConfigItem::Permission
    Kernel::System::ITSMConfigItem::Version
    Kernel::System::ITSMConfigItem::XML
);

# core modules
use Storable qw(dclone);
use List::AllUtils qw(first true);

# CPAN modules

# OTOBO modules
use Kernel::System::VariableCheck qw(:all);

our @ObjectDependencies = (
    'Kernel::Config',
    'Kernel::System::DB',
    'Kernel::System::DynamicField',
    'Kernel::System::DynamicField::Backend',
    'Kernel::System::Cache',
    'Kernel::System::GeneralCatalog',
    'Kernel::System::ITSMConfigItem',
    'Kernel::System::LinkObject',
    'Kernel::System::Log',
    'Kernel::System::Main',
    'Kernel::System::Service',
    'Kernel::System::Ticket::TicketSearch',
    'Kernel::System::User',
    'Kernel::System::VirtualFS',
    'Kernel::System::XML',
);

=head2 new()

create an object

    use Kernel::System::ObjectManager;

    local $Kernel::OM = Kernel::System::ObjectManager->new();
    my $CheckObject = $Kernel::OM->Get('Kernel::System::ITSMConfigItem::Permission::ItemClassGroupCheck');

=cut

sub new {
    my ( $Type, %Param ) = @_;

    # allocate new hash for object
    return bless {}, $Type;
}

=head1 NAME

Kernel::System::ITSMConfigItem::ConfigItemTicket - library for ITSM config items.

=head1 DESCRIPTION

All config item functions. Note that additional parent modules are loaded
which effectively add more methods.

=head1 PUBLIC INTERFACE

=head2 ConfigItemsLinkedToTickets()

return a config item list as array hash reference of items linked to any ticket

    my $ConfigItemsLinkedToTickets = $ConfigItemObject->ConfigItemsLinkedToTickets(
        ClassID => 123,
    );

=cut

sub ConfigItemsLinkedToTickets {
    my ( $Self, %Param ) = @_;

    # get needed objects
    my $ConfigObject = $Kernel::OM->Get('Kernel::Config');
    my $ParamObject  = $Kernel::OM->Get('Kernel::System::Web::Request');

    my $Config = $ConfigObject->Get("OpenStreetMap::ActionConfig");
    my $Action = $ParamObject->GetParam( Param => 'OriginalAction' );

    # check needed stuff
    if ( !$Param{ClassID} ) {
        $Kernel::OM->Get('Kernel::System::Log')->Log(
            Priority => 'error',
            Message  => 'Need ClassID!',
        );
        return;
    }

    my $ConfigAction;
    for my $ConfigKey (keys %{$Config}) {
        next if $Config->{$ConfigKey}->{Action} ne $Action;
        $ConfigAction = $Config->{$ConfigKey};
        last;
    }

    if ( !$ConfigAction ) {
        $Kernel::OM->Get('Kernel::System::Log')->Log(
            Priority => 'error',
            Message  => 'No permission!',
        );
        return;
    }

    for my $Argument (qw(Queues TicketTypes)) {
        if ( !defined $ConfigAction->{$Argument} ) {
            $Kernel::OM->Get('Kernel::System::Log')->Log(
                Priority => 'error',
                Message  => "Need $Argument!",
            );
            return;
        }
    }

    # get state list
    my $StateList = $Kernel::OM->Get('Kernel::System::GeneralCatalog')->ItemList(
        Class       => 'ITSM::ConfigItem::DeploymentState',
        Preferences => {
            Functionality => [ 'preproductive', 'productive' ],
        },
    );

    # create state string
    my $DeplStateString = join q{, }, keys %{$StateList};

    my %SearchCriteria = ();
    if (@{$ConfigAction->{Queues}}) {
        $SearchCriteria{Queues} = $ConfigAction->{Queues};
    }
    if (@{$ConfigAction->{TicketTypes}}) {
        $SearchCriteria{Types} = $ConfigAction->{TicketTypes};
    }

    my @TicketIDs = $Kernel::OM->Get('Kernel::System::Ticket')->TicketSearch(
        Result => 'ARRAY',
        StateType => 'Open',
        UserID => $Param{UserID},
        %SearchCriteria,
    );

    my %ConfigItemIDHash;
    for my $TicketID (@TicketIDs) {
        my @LinkedConfigItems = $Kernel::OM->Get('Kernel::System::LinkObject')->LinkList(
            Object    => 'Ticket',
            Key       => $TicketID,
            Object2   => 'ITSMConfigItem',
            State     => 'Valid',
            UserID => $Param{UserID},
            Direction => "Both",
        );
        for my $LinkedConfigItem (@LinkedConfigItems) {
            next if !%{$LinkedConfigItem};
            for my $Key (keys %{$LinkedConfigItem->{ITSMConfigItem}->{AlternativeTo}->{Source}}) {
                $ConfigItemIDHash{$Key} = 1;
            }
        }
    }
    my @ConfigItemIDList = keys %ConfigItemIDHash;

    # get last versions data
    my @ConfigItemList;
    for my $ConfigItemID (@ConfigItemIDList) {

        # get version data
        my $ConfigItem = $Self->ConfigItemGet(
            ConfigItemID  => $ConfigItemID,
            DynamicFields => 0,
        );

        push @ConfigItemList, $ConfigItem;
    }

    return \@ConfigItemList;
}

1;
