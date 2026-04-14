<?php $this->beginContent('//layouts/main'); ?>
<div class="row g-3">
	<div class="col-lg-9" id="content">
		<?php echo $content; ?>
	</div>
	<div class="col-lg-3" id="sidebar">
		<?php
		$this->beginWidget('zii.widgets.CPortlet', array(
			'title' => 'Operations',
		));
		$this->widget('zii.widgets.CMenu', array(
			'items' => $this->menu,
			'htmlOptions' => array('class' => 'operations'),
		));
		$this->endWidget();
		?>
	</div>
</div>
<?php $this->endContent(); ?>
