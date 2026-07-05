package com.triumphant.android;

import androidx.annotation.NonNull;
import androidx.core.content.FileProvider;

import android.content.ActivityNotFoundException;
import android.content.Intent;
import android.net.Uri;

import java.io.File;

import io.flutter.plugin.common.MethodChannel;
import io.flutter.embedding.engine.FlutterEngine;
import com.ryanheise.audioservice.AudioServiceFragmentActivity;

public class MainActivity extends AudioServiceFragmentActivity {
    private static final String SHARE_CHANNEL = "covenant_of_mercy/share";

    @Override
    public void configureFlutterEngine(@NonNull FlutterEngine flutterEngine) {
        // GeneratedPluginRegistrant.registerWith(flutterEngine);
        super.configureFlutterEngine(flutterEngine);
        new MethodChannel(flutterEngine.getDartExecutor().getBinaryMessenger(), SHARE_CHANNEL)
            .setMethodCallHandler((call, result) -> {
                if ("shareImageToPackage".equals(call.method)) {
                    String packageName = call.argument("packageName");
                    String imagePath = call.argument("imagePath");
                    String text = call.argument("text");
                    result.success(shareImageToPackage(packageName, imagePath, text));
                    return;
                }

                result.notImplemented();
            });
    }

    private boolean shareImageToPackage(String packageName, String imagePath, String text) {
        if (imagePath == null || imagePath.trim().isEmpty()) {
            return false;
        }

        File file = new File(imagePath);
        if (!file.exists()) {
            return false;
        }

        try {
            Uri uri = FileProvider.getUriForFile(
                this,
                getPackageName() + ".provider",
                file
            );

            Intent intent = new Intent(Intent.ACTION_SEND);
            intent.setType("image/*");
            intent.putExtra(Intent.EXTRA_STREAM, uri);
            intent.putExtra(Intent.EXTRA_TEXT, text == null ? "" : text);
            intent.addFlags(Intent.FLAG_GRANT_READ_URI_PERMISSION);

            if (packageName != null && !packageName.trim().isEmpty()) {
                intent.setPackage(packageName);
            }

            startActivity(intent);
            return true;
        } catch (ActivityNotFoundException ignored) {
            return false;
        } catch (Exception ignored) {
            return false;
        }
    }
}
