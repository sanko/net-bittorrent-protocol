# NAME

Net::BitTorrent::Protocol - Basic, Protocol-level BitTorrent Utilities

# Synopsis

```perl
use Net::BitTorrent::Protocol;
...
```

# Functions

In addition to the functions found in [Net::BitTorrent::Protocol::BEP03](https://metacpan.org/pod/Net%3A%3ABitTorrent%3A%3AProtocol%3A%3ABEP03),
[Net::BitTorrent::Protocol::BEP03::Bencode](https://metacpan.org/pod/Net%3A%3ABitTorrent%3A%3AProtocol%3A%3ABEP03%3A%3ABencode), [Net::BitTorrent::Protocol::BEP06](https://metacpan.org/pod/Net%3A%3ABitTorrent%3A%3AProtocol%3A%3ABEP06), [Net::BitTorrent::Protocol::BEP07](https://metacpan.org/pod/Net%3A%3ABitTorrent%3A%3AProtocol%3A%3ABEP07),
[Net::BitTorrent::Protocol::BEP09](https://metacpan.org/pod/Net%3A%3ABitTorrent%3A%3AProtocol%3A%3ABEP09), [Net::BitTorrent::Protocol::BEP10](https://metacpan.org/pod/Net%3A%3ABitTorrent%3A%3AProtocol%3A%3ABEP10), [Net::BitTorrent::Protocol::BEP23](https://metacpan.org/pod/Net%3A%3ABitTorrent%3A%3AProtocol%3A%3ABEP23),
[Net::BitTorrent::Protocol::BEP44](https://metacpan.org/pod/Net%3A%3ABitTorrent%3A%3AProtocol%3A%3ABEP44), [Net::BitTorrent::Protocol::BEP52](https://metacpan.org/pod/Net%3A%3ABitTorrent%3A%3AProtocol%3A%3ABEP52), TODO..., a function which wraps all the
packet parsing functions is provided:

- `parse_packet( \$data )`

    Attempts to parse any known packet from the data (a scalar ref) passed to it. On success, the payload and type are
    returned and the packet is removed from the incoming data reference. `undef` is returned on failure and the data in
    the reference is unchanged.

# Importing from Net::BitTorrent::Protocol

You may import from this module manually...

```perl
use Net::BitTorrent::Protocol 'build_handshake';
```

...or by using one or more of the provided tags:

```perl
use Net::BitTorrent::Protocol ':all';
```

Supported tags include...

- `all`

    Imports everything.

- `build`

    Imports all packet building functions from [BEP03](https://metacpan.org/pod/Net%3A%3ABitTorrent%3A%3AProtocol%3A%3ABEP03),
    [BEP03](https://metacpan.org/pod/Net%3A%3ABitTorrent%3A%3AProtocol%3A%3ABEP05), [BEP06](https://metacpan.org/pod/Net%3A%3ABitTorrent%3A%3AProtocol%3A%3ABEP06),
    [BEP06](https://metacpan.org/pod/Net%3A%3ABitTorrent%3A%3AProtocol%3A%3ABEP09), [BEP10](https://metacpan.org/pod/Net%3A%3ABitTorrent%3A%3AProtocol%3A%3ABEP10), and
    [BEP52](https://metacpan.org/pod/Net%3A%3ABitTorrent%3A%3AProtocol%3A%3ABEP52).

- `bencode`

    Imports the bencode and bdecode functions found in [BEP03](https://metacpan.org/pod/Net%3A%3ABitTorrent%3A%3AProtocol%3A%3ABEP03).

- `compact`

    Imports the compact and inflation functions for IPv4 ([BEP23](https://metacpan.org/pod/Net%3A%3ABitTorrent%3A%3AProtocol%3A%3ABEP23)) and IPv6
    ([BEP07](https://metacpan.org/pod/Net%3A%3ABitTorrent%3A%3AProtocol%3A%3ABEP07)) peer lists.

- `dht`

    Imports all functions related to [BEP05](https://metacpan.org/pod/Net%3A%3ABitTorrent%3A%3AProtocol%3A%3ABEP05) and
    [BEP44](https://metacpan.org/pod/Net%3A%3ABitTorrent%3A%3AProtocol%3A%3ABEP44).

- `parse`

    Imports all packet parsing functions from [BEP03](https://metacpan.org/pod/Net%3A%3ABitTorrent%3A%3AProtocol%3A%3ABEP03),
    [BEP06](https://metacpan.org/pod/Net%3A%3ABitTorrent%3A%3AProtocol%3A%3ABEP06), and [BEP10](https://metacpan.org/pod/Net%3A%3ABitTorrent%3A%3AProtocol%3A%3ABEP10),
    [BEP52](https://metacpan.org/pod/Net%3A%3ABitTorrent%3A%3AProtocol%3A%3ABEP52) as well as the locally defined [`parse_packet( ... )`](#parse_packet-data) function.

- `types`

    Imports the packet type values from [BEP03](https://metacpan.org/pod/Net%3A%3ABitTorrent%3A%3AProtocol%3A%3ABEP03),
    [BEP06](https://metacpan.org/pod/Net%3A%3ABitTorrent%3A%3AProtocol%3A%3ABEP06), and [BEP10](https://metacpan.org/pod/Net%3A%3ABitTorrent%3A%3AProtocol%3A%3ABEP10),
    [BEP52](https://metacpan.org/pod/Net%3A%3ABitTorrent%3A%3AProtocol%3A%3ABEP52).

- `utils`

    Imports the utility functions from [BEP06](https://metacpan.org/pod/Net%3A%3ABitTorrent%3A%3AProtocol%3A%3ABEP06).

# See Also

[AnyEvent::BitTorrent](https://metacpan.org/pod/AnyEvent%3A%3ABitTorrent) - Simple client which uses [Net::BitTorrent::Protocol](https://metacpan.org/pod/Net%3A%3ABitTorrent%3A%3AProtocol)

http://bittorrent.org/beps/bep\_0003.html - The BitTorrent Protocol Specification

http://bittorrent.org/beps/bep\_0006.html - Fast Extension

http://bittorrent.org/beps/bep\_0009.html - Extension for Peers to Send Metadata Files

http://bittorrent.org/beps/bep\_0010.html - Extension Protocol

http://bittorrent.org/beps/bep\_0044.html - Storing arbitrary data in the DHT

http://bittorrent.org/beps/bep\_0052.html - The BitTorrent Protocol Specification v2

http://wiki.theory.org/BitTorrentSpecification - An annotated guide to the BitTorrent protocol

[Net::BitTorrent::PeerPacket](https://metacpan.org/pod/Net%3A%3ABitTorrent%3A%3APeerPacket) - by Joshua McAdams

[Protocol::BitTorrent](https://metacpan.org/pod/Protocol%3A%3ABitTorrent) - by Tom Molesworth

# Author

Sanko Robinson <sanko@cpan.org> - http://sankorobinson.com/

CPAN ID: SANKO

# License and Legal

Copyright (C) 2008-2024 by Sanko Robinson <sanko@cpan.org>

This program is free software; you can redistribute it and/or modify it under the terms of [The Artistic License
2.0](http://www.perlfoundation.org/artistic_license_2_0). See the `LICENSE` file included with this distribution or
[notes on the Artistic License 2.0](http://www.perlfoundation.org/artistic_2_0_notes) for clarification.

When separated from the distribution, all original POD documentation is covered by the [Creative Commons
Attribution-Share Alike 3.0 License](http://creativecommons.org/licenses/by-sa/3.0/us/legalcode). See the
[clarification of the CCA-SA3.0](http://creativecommons.org/licenses/by-sa/3.0/us/).

Neither this module nor the [Author](#author) is affiliated with BitTorrent, Inc.
