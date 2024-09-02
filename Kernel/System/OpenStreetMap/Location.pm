# --
# OTOBO is a web-based ticketing system for service organisations.
# --
# Copyright (C) 2001-2018 OTRS AG, https://otrs.com/
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

package Kernel::System::OpenStreetMap::Location;

use strict;
use warnings;

our @ObjectDependencies = (
    'Kernel::Config',
    'Kernel::System::Log',
    'Kernel::System::GeneralCatalog',
    'Kernel::System::ITSMConfigItem',
    'Kernel::System::Main',
);

=head1 NAME

Kernel::System::OpenStreetMap::Location - Backend for ITSMConfigItem::Location classes containing GPSLongitude and GPSLatitude

=head1 DESCRIPTION

Functions to generate the map section and icon locations.

=head1 PUBLIC INTERFACE

=head2 new()

create an object. Do not use it directly, instead use:

    my $BackendObject = $Kernel::OM->Get('Kernel::System::OpenStreetMap::Location');

=cut

sub new {
    my ( $Type, %Param ) = @_;

    # allocate new hash for object
    my $Self = {};
    bless( $Self, $Type );

    return $Self;
}

=head2 GatherInfo()

Gathers location and icon info.

    my %Info = $BackendObject->GatherInfo(
        Class        => 'Location_Class',
        BackendDef   => $BackendDef,
        ConfigItemID => 123,                                        # optional: only consider ConfigItemID 123, instead of whole class
    );

=cut

sub GatherInfo {
    my ( $Self, %Param ) = @_;

    # check for needed data
    for my $Needed (qw/BackendDef Class/) {
        if ( !defined $Param{$Needed} ) {
            $Kernel::OM->Get('Kernel::System::Log')->Log(
                Priority => 'error',
                Message  => "Need $Needed!",
            );
            return;
        }
    }

    my $ConfigItemObject = $Kernel::OM->Get('Kernel::System::ITSMConfigItem');

    my @CIs;
    if ( $Param{ConfigItemID} ) {
        push @CIs, $ConfigItemObject->ConfigItemGet(
            ConfigItemID => $Param{ConfigItemID},
        );
    }
    elsif ( $Param{ConfigItemIDs} ) {
        for my $ID ( $Param{ConfigItemIDs}->@* ) {
            push @CIs, $ConfigItemObject->ConfigItemGet(
                ConfigItemID => $Param{ConfigItemID},
            );
        }
    }
    else {
        my $GeneralCatalogObject = $Kernel::OM->Get('Kernel::System::GeneralCatalog');
        my %ClassToID            = reverse %{ $GeneralCatalogObject->ItemList( Class => 'ITSM::ConfigItem::Class' ) };

        push @CIs, @{
            $ConfigItemObject->ConfigItemResultList(
                ClassID => $ClassToID{ $Param{Class} },
            )
        };
    }

    my $IconObject;
    if ( $Param{BackendDef}{IconOverride} ) {
        my $OverrideConfig = $Kernel::OM->Get('Kernel::Config')->Get('OpenStreetMap::IconOverride')->{ $Param{BackendDef}{IconOverride} };

        # load the module
        if ( !$Kernel::OM->Get('Kernel::System::Main')->Require( $OverrideConfig->{Module} ) ) {
            $Kernel::OM->Get('Kernel::System::Log')->Log(
                Priority => 'error',
                Message  => "Can't load the override module $OverrideConfig->{Module}!"
            );
            return;
        }

        # create new instance
        $IconObject = $OverrideConfig->{Module}->new(
            %{$OverrideConfig},
        );
    }

    my ( $From, $To, %Icons );
    CI:
    for my $ConfigItem (@CIs) {
        my $Version = $ConfigItemObject->ConfigItemGet(
            VersionID     => $ConfigItem->{LastVersionID},
            DynamicFields => 1,
        );

        my $Latitude  = $Version->{"DynamicField_Location-Latitude"}  || undef;
        my $Longitude = $Version->{"DynamicField_Location-Longitude"} || undef;

        if ( !defined $Latitude || !defined $Longitude ) {
            next CI;
        }

        # define coordinates
        if ( !$From ) {
            $From = [ $Latitude, $Longitude ];
            $To   = [ $Latitude, $Longitude ];
        }
        else {
            if ( $From->[0] > $Latitude )  { $From->[0] = $Latitude }
            if ( $From->[1] > $Longitude ) { $From->[1] = $Longitude }
            if ( $To->[0] < $Latitude )    { $To->[0]   = $Latitude }
            if ( $To->[1] < $Longitude )   { $To->[1]   = $Longitude }
        }

        my $Icon = $Param{BackendDef}{IconPath};
        if ( $Param{BackendDef}{IconOverride} ) {
            my $OverrideIcon = $IconObject->GetIcon(
                Version => $Version,
            );

            if ($OverrideIcon) {
                $Icon = $OverrideIcon;
            }
        }

        # place Icon (LinkSelf only for agents)
        if ($Icon) {
            push @{ $Icons{Path} },      $Icon;
            push @{ $Icons{Latitude} },  $Latitude;
            push @{ $Icons{Longitude} }, $Longitude;
            push @{ $Icons{Link} },
                ( $Param{BackendDef}{LinkSelf} && $Param{UserID} )
                ? "Action=AgentITSMConfigItemZoom;ConfigItemID=$ConfigItem->{ConfigItemID}"
                : '';
            push @{ $Icons{Tooltip} },
                ( $Param{BackendDef}{Tooltip} )
                ? $Version->{Name}
                : '';
        }
    }

    return (
        From  => $From,
        To    => $To,
        Icons => \%Icons,
    );

}

1;

=head1 TERMS AND CONDITIONS

This software is part of the OTOBO project (L<https://otobo.org/>).

This software comes with ABSOLUTELY NO WARRANTY. For details, see
the enclosed file COPYING for license information (GPL). If you
did not receive this file, see L<https://www.gnu.org/licenses/gpl-3.0.txt>.

=cut
