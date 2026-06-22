use embassy_sync::blocking_mutex::raw::CriticalSectionRawMutex;
use embassy_sync::watch::Watch;
use static_cell::StaticCell;
use trouble_host::prelude::*;

// GPS fix pushed by gps::task; peripheral_loop reads it and notifies iOS.
// Encoding: [flags u16 LE | speed cm/s u16 LE | lat i32 LE | lon i32 LE]
// (matches the trimmed Location and Speed characteristic 0x2A67 layout)
pub static GPS_LOCATION: Watch<CriticalSectionRawMutex, [u8; 10], 1> = Watch::new();

#[gatt_server]
pub struct BikeServer {
    cadence: CscService,
    location: LocationService,
}

// Cycling Speed and Cadence — standard SIG service 0x1816.
// iOS's Core Bluetooth will find this without any custom UUID handling.
#[gatt_service(uuid = "1816")]
struct CscService {
    // Flags (1 B) | crank_revs u16 LE | last_crank_event_time u16 LE
    #[characteristic(uuid = "2a5b", read, notify)]
    measurement: [u8; 5],
}

// Location and Navigation — standard SIG service 0x1819.
// Exposes live GPS position + instantaneous speed.
#[gatt_service(uuid = "1819")]
struct LocationService {
    // flags u16 LE | instantaneous_speed u16 LE | lat i32 LE | lon i32 LE
    #[characteristic(uuid = "2a67", read, notify)]
    location_and_speed: [u8; 10],
}

// Extended ad data: flags + service UUIDs + complete local name.
// Extended PDUs have no 31-byte limit so everything fits in one packet.
const ADV_DATA: &[u8] = &[
    0x02, 0x01, 0x06, // Flags: LE General Discoverable, BR/EDR Not Supported
    0x05, 0x03, 0x16, 0x18, 0x19, 0x18, // Complete 16-bit UUIDs: 0x1816, 0x1819
    0x0D, 0x09, b'B', b'i', b'k', b'e', b'C', b'o', b'm', b'p', b'u', b't', b'e', b'r',
];

pub async fn run(stack: &Stack<'_, super::MyController, DefaultPacketPool>) {
    static SERVER: StaticCell<BikeServer<'static>> = StaticCell::new();
    let server = SERVER.init(
        BikeServer::new_with_config(GapConfig::Peripheral(PeripheralConfig {
            name: "BikeComputer",
            appearance: &appearance::cycling::SPEED_AND_CADENCE_SENSOR,
        }))
        .expect("BikeServer init failed"),
    );

    loop {
        log::info!("[BLE peripheral] Advertising...");

        let sets = [AdvertisementSet {
            params: AdvertisementParameters::default(),
            data: Advertisement::ExtConnectableNonscannableUndirected { adv_data: ADV_DATA },
            address: None,
        }];
        let mut handles = AdvertisementSet::handles(&sets);

        let mut peripheral = stack.peripheral();
        let advertiser = match peripheral.advertise_ext(&sets, &mut handles).await {
            Ok(a) => a,
            Err(e) => {
                log::warn!("[BLE peripheral] advertise error: {:?}", e);
                continue;
            }
        };

        let conn = match advertiser.accept().await {
            Ok(c) => c,
            Err(e) => {
                log::warn!("[BLE peripheral] accept error: {:?}", e);
                continue;
            }
        };

        log::info!("[BLE peripheral] iOS connected");
        let gatt_conn = match conn.with_attribute_server(&server.server) {
            Ok(gc) => gc,
            Err(e) => {
                log::warn!("[BLE peripheral] GATT setup error: {:?}", e);
                continue;
            }
        };

        embassy_futures::join::join(
            // Drain GATT events so iOS can do service discovery and subscribe.
            async {
                loop {
                    match gatt_conn.next().await {
                        GattConnectionEvent::Disconnected { .. } => break,
                        GattConnectionEvent::Gatt { event } => {
                            if let Err(e) = event.accept() {
                                log::warn!("[BLE peripheral] GATT reply error: {:?}", e);
                            }
                        }
                        _ => {}
                    }
                }
            },
            // Push live data to iOS as long as it stays connected.
            async {
                notify_loop(stack, server).await;
            },
        )
        .await;

        log::info!("[BLE peripheral] iOS disconnected");
    }
}

async fn notify_loop(
    stack: &Stack<'_, super::MyController, DefaultPacketPool>,
    server: &BikeServer<'_>,
) {
    let mut crank_rx = super::central::CRANK_REVS.receiver().unwrap();
    let mut gps_rx = GPS_LOCATION.receiver().unwrap();
    let mut last_event_time: u16 = 0;

    embassy_futures::join::join(
        async {
            loop {
                let Ok(revs) = crank_rx.changed().await else {
                    continue;
                };
                last_event_time = last_event_time.wrapping_add(1024); // 1 s at 1/1024 s units
                let measurement = [
                    0x02, // Flags: Crank Revolution Data Present
                    revs.to_le_bytes()[0],
                    revs.to_le_bytes()[1],
                    last_event_time.to_le_bytes()[0],
                    last_event_time.to_le_bytes()[1],
                ];
                let handle = server.cadence.measurement.handle;
                if let Err(e) = server.notify(stack, handle, &measurement).await {
                    log::warn!("[BLE peripheral] CSC notify error: {:?}", e);
                    break;
                }
            }
        },
        async {
            loop {
                let fix = gps_rx.changed().await;
                let handle = server.location.location_and_speed.handle;
                if let Err(e) = server.notify(stack, handle, &fix).await {
                    log::warn!("[BLE peripheral] location notify error: {:?}", e);
                    break;
                }
            }
        },
    )
    .await;
}
