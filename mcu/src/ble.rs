pub mod central;
pub mod peripheral;

use bt_hci::cmd::SyncCmd;
use embassy_executor::Spawner;
use embassy_nrf::{mode::Blocking, peripherals, rng, Peri};
use nrf_sdc::mpsl::MultiprotocolServiceLayer;
use nrf_sdc::vendor::ZephyrReadStaticAddrs;
use nrf_sdc::{self as sdc, mpsl};
use static_cell::StaticCell;
use trouble_host::prelude::*;

pub use central::{Error, BATTERY, CRANK_REVS};

pub(crate) type MyController = nrf_sdc::SoftdeviceController<'static>;

#[embassy_executor::task]
async fn mpsl_task(mpsl: &'static MultiprotocolServiceLayer<'static>) -> ! {
    mpsl.run().await
}

#[embassy_executor::task]
async fn ble_task(controller: MyController) {
    let random_addr = match ZephyrReadStaticAddrs::new().exec(&controller).await {
        Ok(r) => Address::new(AddrKind::RANDOM, r.addr.addr),
        Err(e) => {
            log::error!("[BLE] failed to read static addr: {:?}", e);
            return;
        }
    };

    static RESOURCES: StaticCell<HostResources<MyController, DefaultPacketPool, 2, 1>> =
        StaticCell::new();
    let resources = RESOURCES.init(HostResources::new());
    let stack = trouble_host::new(controller, resources)
        .set_random_address(random_addr)
        .build();

    let mut runner = stack.runner();
    let (runner_result, _) = embassy_futures::join::join(
        runner.run_with_handler(&central::CscEventHandler),
        embassy_futures::join::join(central::run(&stack), peripheral::run(&stack)),
    )
    .await;
    if let Err(e) = runner_result {
        log::warn!("[BLE] runner error: {:?}", e);
        CRANK_REVS.sender().send(Err(Error::RunnerCrashed));
    }
}

#[allow(clippy::too_many_arguments)]
pub fn init(
    spawner: Spawner,
    timer0: Peri<'static, peripherals::TIMER0>,
    rtc0: Peri<'static, peripherals::RTC0>,
    temp: Peri<'static, peripherals::TEMP>,
    ppi_ch17: Peri<'static, peripherals::PPI_CH17>,
    ppi_ch18: Peri<'static, peripherals::PPI_CH18>,
    ppi_ch19: Peri<'static, peripherals::PPI_CH19>,
    ppi_ch20: Peri<'static, peripherals::PPI_CH20>,
    ppi_ch21: Peri<'static, peripherals::PPI_CH21>,
    ppi_ch22: Peri<'static, peripherals::PPI_CH22>,
    ppi_ch23: Peri<'static, peripherals::PPI_CH23>,
    ppi_ch24: Peri<'static, peripherals::PPI_CH24>,
    ppi_ch25: Peri<'static, peripherals::PPI_CH25>,
    ppi_ch26: Peri<'static, peripherals::PPI_CH26>,
    ppi_ch27: Peri<'static, peripherals::PPI_CH27>,
    ppi_ch28: Peri<'static, peripherals::PPI_CH28>,
    ppi_ch29: Peri<'static, peripherals::PPI_CH29>,
    ppi_ch30: Peri<'static, peripherals::PPI_CH30>,
    ppi_ch31: Peri<'static, peripherals::PPI_CH31>,
    rng_periph: Peri<'static, peripherals::RNG>,
) -> Result<(), Error> {
    let mpsl_p = mpsl::Peripherals::new(rtc0, timer0, temp, ppi_ch19, ppi_ch30, ppi_ch31);
    let lfclk_cfg = mpsl::raw::mpsl_clock_lfclk_cfg_t {
        source: mpsl::raw::MPSL_CLOCK_LF_SRC_RC as u8,
        rc_ctiv: mpsl::raw::MPSL_RECOMMENDED_RC_CTIV as u8,
        rc_temp_ctiv: mpsl::raw::MPSL_RECOMMENDED_RC_TEMP_CTIV as u8,
        accuracy_ppm: mpsl::raw::MPSL_DEFAULT_CLOCK_ACCURACY_PPM as u16,
        skip_wait_lfclk_started: mpsl::raw::MPSL_DEFAULT_SKIP_WAIT_LFCLK_STARTED != 0,
    };
    static MPSL: StaticCell<MultiprotocolServiceLayer<'static>> = StaticCell::new();
    let mpsl = MPSL.init(
        mpsl::MultiprotocolServiceLayer::new(mpsl_p, crate::Irqs, lfclk_cfg)
            .map_err(|_| Error::MpslInitFailed)?,
    );
    spawner.spawn(mpsl_task(mpsl).map_err(|_| Error::SpawnFailed)?);

    let sdc_p = sdc::Peripherals::new(
        ppi_ch17, ppi_ch18, ppi_ch20, ppi_ch21, ppi_ch22, ppi_ch23, ppi_ch24, ppi_ch25, ppi_ch26,
        ppi_ch27, ppi_ch28, ppi_ch29,
    );

    static RNG_CELL: StaticCell<rng::Rng<'static, Blocking>> = StaticCell::new();
    let rng_ref = RNG_CELL.init(rng::Rng::new_blocking(rng_periph));

    static SDC_MEM: StaticCell<sdc::Mem<8192>> = StaticCell::new();
    let sdc = sdc::Builder::new()
        .map_err(|_| Error::SdcInitFailed)?
        .support_ext_scan()
        .support_central()
        .central_count(1)
        .map_err(|_| Error::SdcInitFailed)?
        .support_adv()
        .support_ext_adv()
        .support_peripheral()
        .peripheral_count(1)
        .map_err(|_| Error::SdcInitFailed)?
        .build(sdc_p, rng_ref, mpsl, SDC_MEM.init(sdc::Mem::new()))
        .map_err(|_| Error::SdcInitFailed)?;

    spawner.spawn(ble_task(sdc).map_err(|_| Error::SpawnFailed)?);
    Ok(())
}
