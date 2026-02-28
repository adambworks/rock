#![no_std] // don't link the Rust standard library
#![no_main] // disable all Rust-level entry points
#![feature(abi_x86_interrupt)]

use core::{panic::PanicInfo};



pub mod arch;
pub mod drivers;





#[unsafe(no_mangle)] // don't mangle the name of this function
pub extern "C" fn _start() -> ! {
 arch::interrupts::init_idt();
 //   println!("Hello World");
  //  print!("YAY");
  //  print!("YAYAYAYAY");
    
 unsafe {
        *(0xfffffffffffff as *mut u8) = 42;
    };

    loop {}
}

/// This function is called on panic.
#[panic_handler]
fn panic(_info: &PanicInfo) -> ! {
    print!("\n{}",_info.message());
    
    loop {}
}
