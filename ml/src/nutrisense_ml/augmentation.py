from __future__ import annotations

import tensorflow as tf


@tf.keras.utils.register_keras_serializable(package="nutrisense_ml")
class RandomApply(tf.keras.layers.Layer):
    """Apply an augmentation pipeline to a random subset of each training batch."""

    def __init__(
        self,
        augmentation: tf.keras.layers.Layer,
        probability: float,
        seed: int | None = None,
        **kwargs,
    ) -> None:
        super().__init__(**kwargs)
        if not 0.0 <= probability <= 1.0:
            raise ValueError("probability must be between 0 and 1")
        self.augmentation = augmentation
        self.probability = float(probability)
        self.seed = seed

    def call(self, inputs: tf.Tensor, training: bool | None = None) -> tf.Tensor:
        if training is False or self.probability == 0.0:
            return inputs
        augmented = tf.cast(
            self.augmentation(inputs, training=training), inputs.dtype
        )
        if self.probability == 1.0:
            return augmented
        mask = tf.random.uniform(
            [tf.shape(inputs)[0], 1, 1, 1], seed=self.seed, dtype=tf.float32
        ) < self.probability
        return tf.where(mask, augmented, inputs)

    def get_config(self) -> dict:
        config = super().get_config()
        config.update(
            {
                "augmentation": tf.keras.layers.serialize(self.augmentation),
                "probability": self.probability,
                "seed": self.seed,
            }
        )
        return config

    @classmethod
    def from_config(cls, config: dict) -> "RandomApply":
        config["augmentation"] = tf.keras.layers.deserialize(config["augmentation"])
        return cls(**config)
