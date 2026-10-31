use fframes::{AudioMap, Duration, EncoderOptions, FFramesContext, Frame, MediaDirectory, RenderOptions, Scenes, Svgr, Video};
use std::{error::Error, process::ExitCode};

#[derive(Debug)]
struct Film;
const CHAPTERS: [(&str, &str, &str); 5] = [
    ("A quieter system view", "CPU, RAM and per-GPU processes.", "overview.png"),
    ("Know where the heat is", "Temperatures and fan speeds, together.", "map.png"),
    ("Your settings. Your choice.", "Save a preset. Apply it explicitly.", "profiles.png"),
    ("Watch memory grow", "Local events and optional notifications. Not a leak verdict.", "memory.png"),
    ("Native to Omarchy", "A readable language picker. Four translated catalogs.", "language.png"),
];
impl Video for Film {
    const FPS: usize = 30;
    const WIDTH: usize = 1920;
    const HEIGHT: usize = 1080;
    fn duration(&self) -> Duration<'_> { Duration::Seconds(30.0) }
    fn audio(&self) -> AudioMap<'_> { AudioMap::none() }
    fn define_scenes(&self) -> Scenes<'_> { Scenes::from(Vec::<&dyn fframes::Scene>::new()) }
    fn render_frame<'a>(&'a self, frame: Frame, ctx: &FFramesContext<'a, '_>) -> Svgr<'a> {
        let time = frame.seconds();
        let index = ((time / 6.0) as usize).min(4);
        let local = time - index as f32 * 6.0;
        let entrance = (local / 0.6).clamp(0.0, 1.0);
        let alpha = entrance.min(((6.0-local)/0.35).clamp(0.0,1.0));
        let (title, subtitle, name) = CHAPTERS[index];
        let small = index == 0 || index == 2 || index == 4;
        let (w,h) = if small { (800.0,650.0) } else { (1000.0,722.22) };
        let x = (1920.0-w)/2.0;
        let y = 250.0 + 20.0*(1.0-entrance);
        let visual = match ctx.get_image(name) {
            Some(asset) => fframes::svgr!(<image href={asset.href()} x={x} y={y} width={w} height={h} preserveAspectRatio="xMidYMid meet" />),
            None => Svgr::empty(),
        };
        fframes::svgr!(
            <svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 1920 1080" width={ctx.current_video_size.width} height={ctx.current_video_size.height}>
                <rect width="1920" height="1080" fill="#15151b" />
                <text x="76" y="66" font-family="DM Sans" font-size="28" fill="#eee3cf">"Loadlet 2.19.2"</text>
                <text x="1844" y="66" text-anchor="end" font-family="DM Sans" font-size="22" fill="#b6afa2">"OMARCHY PLUGIN"</text>
                <g opacity={alpha}>
                    <text x="960" y="146" text-anchor="middle" font-family="DM Sans" font-size="54" font-weight="500" fill="#eee3cf">{title}</text>
                    <text x="960" y="199" text-anchor="middle" font-family="DM Sans" font-size="28" fill="#c9bda9">{subtitle}</text>
                    {visual}
                </g>
                <rect x="76" y="1012" width="1768" height="3" fill="#3b3530" />
                <rect x="76" y="1012" width={(time/30.0*1768.0).max(0.01)} height="3" fill="#d58b4e" />
                <text x="76" y="1053" font-family="DM Sans" font-size="21" fill="#b6afa2">"Native UI with demonstration data. No live recording or cooling guarantee."</text>
                <text x="1844" y="1053" text-anchor="end" font-family="DM Sans" font-size="21" fill="#b6afa2">{format!("{} / 5",index+1)}</text>
            </svg>
        )
    }
}
fn run() -> Result<ExitCode, Box<dyn Error>> {
    let directory = MediaDirectory::read_folder("media")?;
    let media = directory.process_media_source()?;
    Ok(fframes::cli::new(&Film,RenderOptions {
        media: Some(&media), default_font: "DM Sans", load_system_fonts: false,
        video_encoder_options: EncoderOptions {
            preferred_encoder: Some("libx264"), codec_params: Some(&[("crf","18"),("preset","fast")]),
            ..Default::default()
        }, ..Default::default()
    }).default_output("out/loadlet-2.19.2.mp4").run())
}
fn main() -> ExitCode {
    match run() { Ok(code) => code, Err(error) => { eprintln!("{error}"); ExitCode::FAILURE } }
}
