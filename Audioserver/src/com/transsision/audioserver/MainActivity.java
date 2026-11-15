package com.transsision.audioserver;

import android.app.Activity;
import android.media.audiofx.Equalizer;
import android.os.Bundle;
import android.text.InputType;
import android.view.View;
import android.widget.Button;
import android.widget.EditText;
import android.widget.LinearLayout;
import android.widget.SeekBar;
import android.widget.TextView;

public class MainActivity extends Activity {
    private Equalizer equalizer;
    private LinearLayout layout;

    @Override
    protected void onCreate(Bundle savedInstanceState) {
        super.onCreate(savedInstanceState);
        setContentView(R.layout.main);
        layout = findViewById(R.id.layout_root);
        setupEqualizer();
    }

    private void setupEqualizer() {
        equalizer = new Equalizer(0, 0);
        equalizer.setEnabled(true);

        short[] range = equalizer.getBandLevelRange();
        final short minLevel = range[0];
        final short maxLevel = range[1];
        short bands = equalizer.getNumberOfBands();

        for (short i = 0; i < bands; i++) {
            final short band = i;
            int freqHz = equalizer.getCenterFreq(band) / 1000;

            TextView freqLabel = new TextView(this);
            freqLabel.setText(freqHz + " Hz");
            freqLabel.setPadding(0, 16, 0, 0);
            layout.addView(freqLabel);

            final TextView valueLabel = new TextView(this);
            short currentLevel = equalizer.getBandLevel(band);
            valueLabel.setText("Level: " + (currentLevel / 100.0f) + " dB");
            layout.addView(valueLabel);

            final SeekBar bar = new SeekBar(this);
            bar.setMax(maxLevel - minLevel);
            bar.setProgress(currentLevel - minLevel);
            layout.addView(bar);

            final EditText inputField = new EditText(this);
            inputField.setHint("Enter level in mB (" + minLevel + " to " + maxLevel + ")");
            inputField.setInputType(InputType.TYPE_CLASS_NUMBER | InputType.TYPE_NUMBER_FLAG_SIGNED);
            layout.addView(inputField);

            Button applyBtn = new Button(this);
            applyBtn.setText("Apply");
            layout.addView(applyBtn);

            bar.setOnSeekBarChangeListener(new SeekBar.OnSeekBarChangeListener() {
                @Override
                public void onProgressChanged(SeekBar seekBar, int progress, boolean fromUser) {
                    short level = (short) (progress + minLevel);
                    equalizer.setBandLevel(band, level);
                    valueLabel.setText("Level: " + (level / 100.0f) + " dB");
                }

                @Override
                public void onStartTrackingTouch(SeekBar seekBar) {}

                @Override
                public void onStopTrackingTouch(SeekBar seekBar) {}
            });

            applyBtn.setOnClickListener(new View.OnClickListener() {
                @Override
                public void onClick(View v) {
                    try {
                        int val = Integer.parseInt(inputField.getText().toString());
                        if (val >= minLevel && val <= maxLevel) {
                            equalizer.setBandLevel(band, (short) val);
                            valueLabel.setText("Level: " + (val / 100.0f) + " dB");
                            bar.setProgress(val - minLevel);
                        } else {
                            inputField.setError("Range: " + (minLevel / 100.0f) + " to " + (maxLevel / 100.0f) + " dB");
                        }
                    } catch (Exception e) {
                        inputField.setError("Invalid input");
                    }
                }
            });
        }
    }

    @Override
    protected void onDestroy() {
        if (equalizer != null) {
            equalizer.release();
        }
        super.onDestroy();
    }
}
