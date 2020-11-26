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

package Kernel::System::OpenStreetMap::Icons::BasicCIInfo;

use strict;
use warnings;

our @ObjectDependencies = (
    'Kernel::System::Log',
    'Kernel::System::GeneralCatalog',
    'Kernel::System::ITSMConfigItem',
);

=head1 NAME

Kernel::System::OpenStreetMap::Icons::BasicCIInfo

=head1 DESCRIPTION

Defines which icons to use, based on states.

=head1 PUBLIC INTERFACE

=head2 new()

create an object. 

    my $IconObject = Kernel::System::OpenStreetMap::Icons::BasicCIInfo->new(
        %Param,
    );

=cut

sub new {
    my ( $Type, %Param ) = @_;

    # allocate new hash for object
    my $Self = \%Param;
    bless( $Self, $Type );

    return $Self;
}

=head2 GetIcon()

Returns the icon path info.

    my $IconPath = $IconObject->GetIcon(
        Version => $Version,
    );

=cut

sub GetIcon {
    my ( $Self, %Param ) = @_;

    # check for needed data
    for my $Needed (qw/Version/) {
        if ( !defined $Param{$Needed} ) {
            $Kernel::OM->Get('Kernel::System::Log')->Log(
                Priority => 'error',
                Message  => "Need $Needed!",
            );
            return;
        }
    }

    STATE:
    for my $Name ( keys %{ $Self->{States} } ) {
        for my $Attr ( keys %{ $Self->{States}{ $Name } } ) {
            if ( !$Param{Version}{ $Attr } || $Param{Version}{ $Attr } ne $Self->{States}{ $Name }{ $Attr } ) {
                next STATE;
            }
        }

        # we fullfill all requirements here
        return $Self->{IconPaths}{ $Name } if $Self->{IconPaths}{ $Name };
    }
    
    return;
}

1;

