# --
# OTOBO is a web-based ticketing system for service organisations.
# --
# Copyright (C) 2001-2018 OTRS AG, https://otrs.com/
# Copyright (C) 2019-2020 Rother OSS GmbH, https://otobo.de/
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

package Kernel::System::OpenStreetMap::Section;

use strict;
use warnings;

our @ObjectDependencies = (
    'Kernel::System::Log',
    'Kernel::Config',
    'Kernel::System::GeneralCatalog',
    'Kernel::System::ITSMConfigItem',
    'Kernel::System::LinkObject',
);

=head1 NAME

Kernel::System::OpenStreetMap::Section - Backend for ITSMConfigItem classes linked to two locations

=head1 DESCRIPTION

Functions to generate the map section and icon locations.

=head1 PUBLIC INTERFACE

=head2 new()

create an object. Do not use it directly, instead use:

    my $BackendObject = $Kernel::OM->Get('Kernel::System::OpenStreetMap::Section');

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
        Class        => 'Line_Class',
        BackendDef   => $BackendDef,
        IconPath     => 'var/httpd/htdocs/RotherOSS-OpenStreetMap/' # optional
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
    my $LinkObject       = $Kernel::OM->Get('Kernel::System::LinkObject');
    my $ParentClass      = $Param{BackendDef}{LocationInfo}{LinkedClasses}[0];

    # sections are drawn as parts of the linked class, they need to be gathered first
    my @CIs;
    if ( $Param{ConfigItemID} ) {
        my $LinkList = $LinkObject->LinkListWithData(
            Object => 'ITSMConfigItem',
            Key    => $Param{ConfigItemID},
            State  => 'Valid',
            UserID => 1,
        );

        LINKS:
        for my $LTypes ( values %{$LinkList} ) {
            for my $LDirs ( values %{$LTypes} ) {
                for my $CINums ( values %{$LDirs} ) {
                    for my $LinkedItem ( values %{$CINums} ) {

                        if ( $LinkedItem->{Class} eq $ParentClass ) {
                            @CIs = (
                                $ConfigItemObject->ConfigItemGet( ConfigItemID => $LinkedItem->{ConfigItemID} ),
                            );
                            last LINKS;
                        }

                    }
                }
            }
        }

        if ( !@CIs ) {
            $Kernel::OM->Get('Kernel::System::Log')->Log(
                Priority => 'notice',
                Message =>
                    "No link of class $Param{BackendDef}{LocationInfo}{LinkedClasses}[0] found for ConfigItemID $Param{ConfigItemID}!",
            );
            return;
        }
    }
    else {
        my $GeneralCatalogObject = $Kernel::OM->Get('Kernel::System::GeneralCatalog');
        my %ClassToID            = reverse %{ $GeneralCatalogObject->ItemList( Class => 'ITSM::ConfigItem::Class' ) };

        push @CIs, @{
            $ConfigItemObject->ConfigItemResultList(
                ClassID => $ClassToID{$ParentClass},
            )
        };
    }

    # get the configurations for the class backends
    my $ConfigObject = $Kernel::OM->Get('Kernel::Config');
    my %LinkBackendDef
        = map { $_->{Class} => $_ } values %{ $ConfigObject->Get('RotherOSSOpenStreetMap::ClassConfig') };
    my $ParentObject = $Kernel::OM->Get( $LinkBackendDef{$ParentClass}{Backend} );

    my ( $From, $To, %Icons, %Lines );

    # cycle through the parent CIs
    CI:
    for my $ConfigItem (@CIs) {

        my %ParentInfo = $ParentObject->GatherInfo(
            Class        => $ParentClass,
            BackendDef   => $LinkBackendDef{$ParentClass},
            ConfigItemID => $ConfigItem->{ConfigItemID},
        );

        my $LinkList = $LinkObject->LinkListWithData(
            Object => 'ITSMConfigItem',
            Key    => $ConfigItem->{ConfigItemID},
            State  => 'Valid',
            UserID => 1,
        );

        my @Sections;

    # hier weiter...
    #        LINKS:
    #        for my $LTypes ( values %{ $LinkList } ) {
    #          for my $LDirs ( values %{ $LTypes } ) {
    #            for my $CINums ( values %{ $LDirs } ) {
    #              for my $LinkedItem ( values %{ $CINums } ) {
    #
    #                if ( !$Ends[0] && $LinkedItem->{Class} eq $Param{BackendDef}{LocationInfo}{LinkedClasses} ) {
    #                    $Ends[0] = $LinkedItem->{ConfigItemID};
    #                    if ( $Ends[1] ) {
    #                        last LINKS;
    #                    }
    #                }
    #                elsif ( !$Ends[1] && $LinkedItem->{Class} eq $Param{BackendDef}{LocationInfo}{LinkedClasses}[1] ) {
    #                    $Ends[1] = $LinkedItem->{ConfigItemID};
    #                    if ( $Ends[0] ) {
    #                        last LINKS;
    #                    }
    #                }
    #
    #              }
    #            }
    #          }
    #        }
    #
    }
##use Data::Dumper;
##print STDERR "vo60 - Icons: ".Dumper(\%Icons);
##print STDERR "vo60 - Lines: ".Dumper(\%Lines);
    #
    return (
        From  => $From,
        To    => $To,
        Icons => \%Icons,
        Lines => \%Lines,
    );

}

1;

=head1 TERMS AND CONDITIONS

This software is part of the OTOBO project (L<https://otobo.org/>).

This software comes with ABSOLUTELY NO WARRANTY. For details, see
the enclosed file COPYING for license information (GPL). If you
did not receive this file, see L<https://www.gnu.org/licenses/gpl-3.0.txt>.

=cut
