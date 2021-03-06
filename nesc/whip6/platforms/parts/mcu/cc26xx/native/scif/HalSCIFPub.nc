/*
 * whip6: Warsaw High-performance IPv6.
 *
 * Copyright (c) 2012-2017 Szymon Acedanski
 * All rights reserved.
 *
 * This file is distributed under the terms in the attached LICENSE     
 * files.
 */
#include "aon_event.h"

generic configuration HalSCIFPub() {
    provides interface SCIF;
}
implementation {
    // TODO: in the far future, support switching drivers, for now multiple
    //       drivers should result in compilation errors.

    components HalSCIFPrv as Prv;
    SCIF = Prv.SCIF;

    components HplAUXInterruptsPub as Ints;
    Prv.ReadyEvent -> Ints.SW0Int;
    Prv.AlertEvent -> Ints.SW1Int;

    components new CC26xxWakeUpSourcePub(AON_EVENT_AUX_SWEV0) as SW0Wake;
    Prv.SW0WakeUpSource -> SW0Wake;
    components new CC26xxWakeUpSourcePub(AON_EVENT_AUX_SWEV1) as SW1Wake;
    Prv.SW1WakeUpSource -> SW1Wake;
}
