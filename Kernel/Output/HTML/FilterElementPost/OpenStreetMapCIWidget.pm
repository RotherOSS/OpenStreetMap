# --
# OTOBO is a web-based ticketing system for service organisations.
# --
# Copyright (C) 2020 Rother OSS GmbH, http://rother-oss.com/
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

package Kernel::Output::HTML::FilterElementPost::OpenStreetMapCIWidget;

use strict;
use warnings;

our @ObjectDependencies = (
    'Kernel::Config',
    'Kernel::Output::HTML::Layout',
    'Kernel::System::ITSMConfigItem',
);

sub new {
    my ( $Type, %Param ) = @_;

    # allocate new hash for object
    my $Self = {%Param};
    bless( $Self, $Type );

    return $Self;
}

sub Run {
    my ( $Self, %Param ) = @_;

    my $ConfigObject     = $Kernel::OM->Get('Kernel::Config');
    my $ConfigItemObject = $Kernel::OM->Get('Kernel::System::ITSMConfigItem');

    # get the active classes
    my $ShowMapClasses = $ConfigObject->Get('OpenStreetMap::ShowForClasses');
    return 1 if !$ShowMapClasses;

    # get the version of the shown CI
    $Self->{RequestedURL} =~ /ConfigItemID=(\d+)/;
    return 1 if !$1;

    my $Version = $ConfigItemObject->VersionGet(
        ConfigItemID => $1,
        XMLDataGet   => 0,
    );

    # insert map if CI belongs to active class
    if ( $ShowMapClasses->{ 'ITSMConfigItem::' . $Version->{Class} } ) {
        my $OSMCanvas = $Self->{LayoutObject}->Output(
            TemplateFile => 'OpenStreetMapWidget',
            Data         => {},
        );

        # insert at the last position of the sidebar column
        ${ $Param{Data} } =~ s/^(\s+<\/div>\s*\n\s+<div class="ContentColumn">)/$OSMCanvas\n$1/m;
    }

    return 1;
}

1;
