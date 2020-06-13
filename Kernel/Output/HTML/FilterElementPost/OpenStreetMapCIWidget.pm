# --
# Copyright (C) 2020 Rother OSS GmbH, http://rother-oss.com/
# --
# This software comes with ABSOLUTELY NO WARRANTY. For details, see
# the enclosed file COPYING for license information (GPL). If you
# did not receive this file, see https://www.gnu.org/licenses/gpl-3.0.txt.
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
    my $ShowMapClasses = $ConfigObject->Get('RotherOSSOpenStreetMap::ShowForClasses');
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
