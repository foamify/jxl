// This is the entry point of your Rust library.
// When adding new code to your project, note that only items used
// here will be transformed to their Dart equivalents.

use std::{
    collections::HashMap,
    io::Cursor,
    sync::{
        mpsc::{self, Receiver, Sender},
        RwLock,
    },
    thread,
};

use flutter_rust_bridge::{frb, ZeroCopyBuffer};
pub use jxl_oxide::{CropInfo, JxlImage};

lazy_static::lazy_static! {
    static ref DECODERS: RwLock<HashMap<String, JxlDecoder>> = {
        RwLock::new(HashMap::new())
    };
}

pub fn init_decoder(jxl_bytes: Vec<u8>, key: String) -> JxlInfo {
    {
        let map = DECODERS.read().unwrap();
        if map.contains_key(&key) {
            let decoder = &map[&key];
            return decoder.info;
        }
    }

    let (decoder_request_tx, decoder_request_rx): (
        Sender<DecoderRequest>,
        Receiver<DecoderRequest>,
    ) = mpsc::channel();
    let (decoder_response_tx, decoder_response_rx): (
        Sender<CodecResponse>,
        Receiver<CodecResponse>,
    ) = mpsc::channel();
    let (decoder_info_tx, decoder_info_rx): (Sender<JxlInfo>, Receiver<JxlInfo>) = mpsc::channel();

    thread::spawn(move || {
        let reader = Cursor::new(jxl_bytes);
        let image = JxlImage::from_reader(reader).expect("Failed to decode image");
        let width = image.width();
        let height = image.height();
        let image_count = image.num_loaded_frames();
        let is_animation = image.image_header().metadata.animation.is_some();
        let is_hdr = image.image_header().metadata.bit_depth.bits_per_sample() > 8;
        let mut duration = 0.0;
        if is_animation {
            let ticks = image.frame_header(0).unwrap().duration;
            let tps_numerator = image
                .image_header()
                .metadata
                .animation
                .as_ref()
                .unwrap()
                .tps_numerator;
            let tps_denominator = image
                .image_header()
                .metadata
                .animation
                .as_ref()
                .unwrap()
                .tps_denominator;
            duration = ticks as f64 / (tps_numerator as f64 / tps_denominator as f64);
        }

        let mut decoder = Decoder {
            image,
            index: 0,
            count: image_count,
        };

        // ---

        match decoder_info_tx.send(JxlInfo {
            width,
            height,
            duration,
            image_count,
            is_hdr,
        }) {
            Ok(result) => result,
            Err(e) => panic!("Decoder connection lost. {}", e),
        };

        loop {
            let request = decoder_request_rx.recv().unwrap();
            let response = match request.command {
                DecoderCommand::GetNextFrame => _get_next_frame(&mut decoder, request.crop_info),
                DecoderCommand::Reset => _reset_decoder(),
                DecoderCommand::Dispose => _dispose_decoder(),
            };
            match decoder_response_tx.send(response) {
                Ok(result) => result,
                Err(e) => panic!("Decoder connection lost. {}", e),
            };

            if let DecoderCommand::Dispose = request.command {
                break;
            }
        }
    });

    let jxl_info = match decoder_info_rx.recv() {
        Ok(result) => result,
        Err(e) => panic!("Couldn't read jxl info. Code: {}", e),
    };

    {
        let mut map = DECODERS.write().unwrap();
        map.insert(
            key,
            JxlDecoder {
                request_tx: decoder_request_tx,
                response_rx: decoder_response_rx,
                info: jxl_info,
            },
        );
    }
    jxl_info
}

pub fn reset_decoder(key: String) -> bool {
    let map = DECODERS.read().unwrap();
    if !map.contains_key(&key) {
        return false;
    }

    let decoder = &map[&key];
    match decoder.request_tx.send(DecoderRequest {
        crop_info: None,
        command: DecoderCommand::Reset,
    }) {
        Ok(result) => result,
        Err(e) => panic!("Decoder connection lost. {}", e),
    };
    decoder.response_rx.recv().unwrap();
    true
}

pub fn dispose_decoder(key: String) -> bool {
    let mut map = DECODERS.write().unwrap();
    if !map.contains_key(&key) {
        return false;
    }

    let decoder = &map[&key];
    match decoder.request_tx.send(DecoderRequest {
        crop_info: None,
        command: DecoderCommand::Dispose,
    }) {
        Ok(result) => result,
        Err(e) => panic!("Decoder connection lost. {}", e),
    };
    decoder.response_rx.recv().unwrap();
    map.remove(&key);
    true
}

pub fn get_next_frame(key: String, crop_info: Option<CropInfo>) -> Frame {
    let map = DECODERS.read().unwrap();
    if !map.contains_key(&key) {
        panic!("Decoder not found. {}", key);
    }

    let decoder = &map[&key];

    match decoder.request_tx.send(DecoderRequest {
        command: DecoderCommand::GetNextFrame,
        crop_info,
    }) {
        Ok(result) => result,
        Err(e) => panic!("Decoder connection lost. {}", e),
    };
    let result = decoder.response_rx.recv().unwrap();
    result.frame
}

fn _dispose_decoder() -> CodecResponse {
    CodecResponse {
        frame: Frame {
            data: ZeroCopyBuffer(Vec::new()),
            duration: 0.0,
            width: 0,
            height: 0,
        },
    }
}

fn _reset_decoder() -> CodecResponse {
    CodecResponse {
        frame: Frame {
            data: ZeroCopyBuffer(Vec::new()),
            duration: 0.0,
            width: 0,
            height: 0,
        },
    }
}

fn _get_next_frame(decoder: &mut Decoder, crop: Option<CropInfo>) -> CodecResponse {
    let image = &decoder.image;

    let next = (decoder.index + 1) % decoder.count;

    decoder.index = next;

    let render = image
        .render_frame_cropped(next, crop)
        .expect("Failed to render frame");

    let render_image = render.image_all_channels();

    let _data = render_image.buf().to_vec();

    image.rendered_icc();

    CodecResponse {
        frame: Frame {
            data: ZeroCopyBuffer(_data),
            duration: render.duration() as f64,
            width: render_image.width() as u32,
            height: render_image.height() as u32,
        },
    }
}

pub fn is_jxl(jxl_bytes: Vec<u8>) -> bool {
    let reader = Cursor::new(jxl_bytes);
    let image = JxlImage::from_reader(reader);

    image.is_ok()
}

pub struct Frame {
    pub data: ZeroCopyBuffer<Vec<f32>>,
    pub duration: f64,
    pub width: u32,
    pub height: u32,
}

#[derive(Copy, Clone)]
pub struct JxlInfo {
    pub width: u32,
    pub height: u32,
    pub image_count: usize,
    pub duration: f64,
    pub is_hdr: bool,
}

pub struct Decoder {
    image: JxlImage,
    index: usize,
    count: usize,
}

pub struct JxlDecoder {
    request_tx: Sender<DecoderRequest>,
    response_rx: Receiver<CodecResponse>,
    info: JxlInfo,
}

unsafe impl Send for JxlDecoder {}
unsafe impl Sync for JxlDecoder {}

enum DecoderCommand {
    GetNextFrame,
    Reset,
    Dispose,
}

struct CodecResponse {
    pub frame: Frame,
}

#[frb(mirror(CropInfo))]
pub struct _CropInfo {
    pub width: u32,
    pub height: u32,
    pub left: u32,
    pub top: u32,
}

struct DecoderRequest {
    crop_info: Option<CropInfo>,
    command: DecoderCommand,
}
