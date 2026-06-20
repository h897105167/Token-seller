# Generate all game icons using text_to_image API
$baseDir = "d:\GodotProjects\tokens-saler\assets\icons"
$apiBase = "https://trae-api-cn.mchost.guru/api/ide/v1/text_to_image"

# Create directories
$dirs = @("items", "techs/input", "techs/universal")
foreach ($d in $dirs) {
    $path = Join-Path $baseDir $d
    if (-not (Test-Path $path)) {
        New-Item -ItemType Directory -Path $path -Force | Out-Null
    }
}

# Define all icons: path and prompt
$icons = @(
    @{path="items/keyboard.png"; prompt="anime style game icon, cute mechanical keyboard with RGB lighting, white background, clean illustration, 128x128"}
    @{path="items/microphone.png"; prompt="anime style game icon, cute microphone with sound waves, white background, clean illustration, 128x128"}
    @{path="items/programmer.png"; prompt="anime style game icon, cute programmer character with laptop coding, white background, clean illustration, 128x128"}
    @{path="items/pipeline.png"; prompt="anime style game icon, factory conveyor belt with gears and tokens, white background, clean illustration, 128x128"}
    @{path="items/ai_company.png"; prompt="anime style game icon, modern tech company building with AI brain symbol, white background, clean illustration, 128x128"}
    @{path="items/data_center.png"; prompt="anime style game icon, server racks with glowing blue lights, white background, clean illustration, 128x128"}
    @{path="items/nvotia.png"; prompt="anime style game icon, futuristic GPU graphics card glowing green, white background, clean illustration, 128x128"}
    @{path="items/exchange.png"; prompt="anime style game icon, stock exchange building with rising charts, white background, clean illustration, 128x128"}
    @{path="items/bank.png"; prompt="anime style game icon, grand bank building with classical columns, white background, clean illustration, 128x128"}
    @{path="items/token_nation.png"; prompt="anime style game icon, futuristic nation cityscape with token symbols floating, white background, clean illustration, 128x128"}
    @{path="items/spaceship.png"; prompt="anime style game icon, sleek spaceship launching with flames, white background, clean illustration, 128x128"}
    @{path="items/terraform.png"; prompt="anime style game icon, planet being terraformed with green patches appearing, white background, clean illustration, 128x128"}
    @{path="items/ether_circuit.png"; prompt="anime style game icon, glowing ethereal circuit board with mystical energy, white background, clean illustration, 128x128"}
    @{path="items/token_ascension.png"; prompt="anime style game icon, human brain transforming into golden digital tokens ascending, white background, clean illustration, 128x128"}
    @{path="items/time_machine.png"; prompt="anime style game icon, steampunk time machine with clock gears and portal, white background, clean illustration, 128x128"}
    @{path="items/ideal_machine.png"; prompt="anime style game icon, perfect mechanical device glowing with golden energy, white background, clean illustration, 128x128"}
    @{path="items/universe_replicator.png"; prompt="anime style game icon, multiple universes being copied and replicated, white background, clean illustration, 128x128"}
    @{path="items/truth_gate.png"; prompt="anime style game icon, mystical gate radiating golden knowledge light, white background, clean illustration, 128x128"}
    @{path="items/wish_machine.png"; prompt="anime style game icon, magical wish-granting machine with stars and sparkles, white background, clean illustration, 128x128"}
    @{path="items/you.png"; prompt="anime style game icon, mysterious silhouette of a person radiating cosmic power, white background, clean illustration, 128x128"}
    @{path="techs/input/input_1.png"; prompt="anime style game icon, cute hand cream tube with sparkles, white background, clean illustration, 128x128"}
    @{path="techs/input/input_2.png"; prompt="anime style game icon, hands and feet typing on keyboard frantically, white background, clean illustration, 128x128"}
    @{path="techs/input/input_3.png"; prompt="anime style game icon, warm insulated winter gloves glowing softly, white background, clean illustration, 128x128"}
    @{path="techs/input/input_4.png"; prompt="anime style game icon, robotic mechanical fingers with metal joints, white background, clean illustration, 128x128"}
    @{path="techs/input/input_5.png"; prompt="anime style game icon, fingers shooting red laser beams, white background, clean illustration, 128x128"}
    @{path="techs/input/input_6.png"; prompt="anime style game icon, brain wave controlled glowing blue fingers, white background, clean illustration, 128x128"}
    @{path="techs/input/input_7.png"; prompt="anime style game icon, digital cybernetic fingers made of green code, white background, clean illustration, 128x128"}
    @{path="techs/input/input_8.png"; prompt="anime style game icon, versatile golden fingers radiating energy, white background, clean illustration, 128x128"}
    @{path="techs/input/input_9.png"; prompt="anime style game icon, fingers with purple black hole gravity swirl, white background, clean illustration, 128x128"}
    @{path="techs/input/input_10.png"; prompt="anime style game icon, fingers radiating white truth light beams, white background, clean illustration, 128x128"}
    @{path="techs/input/input_11.png"; prompt="anime style game icon, magical wish-granting fingers with rainbow stars, white background, clean illustration, 128x128"}
    @{path="techs/input/input_12.png"; prompt="anime style game icon, ultimate transcendent cosmic fingers radiating galaxy energy, white background, clean illustration, 128x128"}
    @{path="techs/universal/universal_1.png"; prompt="anime style game icon, thank you letter with pink heart seal, white background, clean illustration, 128x128"}
    @{path="techs/universal/universal_2.png"; prompt="anime style game icon, grateful anime character bowing with sparkles, white background, clean illustration, 128x128"}
    @{path="techs/universal/universal_3.png"; prompt="anime style game icon, golden trophy with thank you ribbon, white background, clean illustration, 128x128"}
    @{path="techs/universal/universal_4.png"; prompt="anime style game icon, golden medal of gratitude with gems, white background, clean illustration, 128x128"}
    @{path="techs/universal/universal_5.png"; prompt="anime style game icon, crystal thank you crystal glowing, white background, clean illustration, 128x128"}
    @{path="techs/universal/universal_6.png"; prompt="anime style game icon, full moon with grateful smiling face, white background, clean illustration, 128x128"}
    @{path="techs/universal/universal_7.png"; prompt="anime style game icon, grateful character holding new graphics card, white background, clean illustration, 128x128"}
    @{path="techs/universal/universal_8.png"; prompt="anime style game icon, 100 days celebration golden badge with fireworks, white background, clean illustration, 128x128"}
    @{path="techs/universal/universal_9.png"; prompt="anime style game icon, supreme god crown of gratitude with cosmic rays, white background, clean illustration, 128x128"}
)

$total = $icons.Count
$success = 0
$failed = 0

for ($i = 0; $i -lt $icons.Count; $i++) {
    $icon = $icons[$i]
    $fullPath = Join-Path $baseDir $icon.path
    $promptEncoded = [uri]::EscapeDataString($icon.prompt)
    $url = "$apiBase`?prompt=$promptEncoded&image_size=square_hd"

    Write-Progress -Activity "Generating icons" -Status "Downloading $($icon.path) ($($i+1)/$total)" -PercentComplete (($i / $total) * 100)

    try {
        Invoke-WebRequest -Uri $url -OutFile $fullPath -TimeoutSec 60 -ErrorAction Stop
        $fileSize = (Get-Item $fullPath).Length
        if ($fileSize -gt 1000) {
            Write-Host "[OK] $($icon.path) ($fileSize bytes)"
            $success++
        } else {
            Write-Host "[WARN] $($icon.path) file too small ($fileSize bytes)"
            $failed++
        }
    } catch {
        Write-Host "[FAIL] $($icon.path) : $($_.Exception.Message)"
        $failed++
    }

    Start-Sleep -Milliseconds 300
}

Write-Host ""
Write-Host "Done: $success success, $failed failed, $total total"
