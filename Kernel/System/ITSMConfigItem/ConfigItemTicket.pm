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

    # check needed stuff
    if ( !$Param{ClassID} ) {
        $Kernel::OM->Get('Kernel::System::Log')->Log(
            Priority => 'error',
            Message  => 'Need ClassID!',
        );
        return;
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

    # ask database
    $Kernel::OM->Get('Kernel::System::DB')->Prepare(
        SQL => "SELECT DISTINCT ci.id FROM configitem ci "
            . "JOIN link_relation lrel on ci.id = lrel.target_key "
            . "JOIN link_object lobj1 on lrel.target_object_id = lobj1.id "
            . "JOIN link_object lobj2 on lrel.source_object_id = lobj2.id "
            . "WHERE lobj1.name = 'ITSMConfigItem' and lobj2.name = 'Ticket' "
            . "UNION "
            . "SELECT DISTINCT ci.id FROM configitem ci "
            . "JOIN link_relation lrel on ci.id = lrel.source_key "
            . "JOIN link_object lobj2 on lrel.target_object_id = lobj2.id "
            . "JOIN link_object lobj1 on lrel.source_object_id = lobj1.id "
            . "WHERE lobj1.name = 'ITSMConfigItem' and lobj2.name = 'Ticket' "
            . "AND class_id = ? AND cur_depl_state_id IN ( $DeplStateString ) ",
        Bind => [ \$Param{ClassID} ],
    );

    # fetch the result
    my @ConfigItemIDList;
    while ( my @Row = $Kernel::OM->Get('Kernel::System::DB')->FetchrowArray() ) {
        push @ConfigItemIDList, $Row[0];
    }

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
