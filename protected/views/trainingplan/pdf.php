	<div id="foto">
		<?php if ($model->client && $model->client->foto): ?>
			<img src="<?php echo $model->client->foto ?>" />
		<?php endif; ?>
	</div>
	<br/>
	<table style="width:100%;" border="0" cellpadding="4">
		<tr>
			<td style="width: 17.5%;"><b><?php echo $model->getAttributeLabel('client_id') ?>:</b></td>
			<td style="width: 17.5%;"><?php echo $model->client ? $model->client->getModelDisplay() : '' ?></td>
			<td style="width: 17.5%;"><b><?php echo $model->getAttributeLabel('new_pro') ?>:</b></td>
			<td style="width: 17.5%;"><?php echo $model->new_pro ?></td>
			<td style="width: 30%;" colspan="6"></td>
		</tr>
		<tr>
			<td style="width: 17.5%;"><b><?php echo $model->getAttributeLabel('load_duration') ?>:</b></td>
			<td style="width: 17.5%;"><?php echo $model->load_duration ?></td>
			<td style="width: 17.5%;"><b><?php echo $model->getAttributeLabel('repeat') ?>:</b></td>
			<td style="width: 17.5%;"><?php echo $model->repeat ?></td>
			<td style="width: 5%;"><b><?php echo $model->getAttributeLabel('temp') ?>:</b></td>
			<td style="width: 5%;"><?php echo $model->temp ?></td>
			<td style="width: 5%;"><b><?php echo $model->getAttributeLabel('rates') ?>:</b></td>
			<td style="width: 5%;"><?php echo $model->rates ?></td>
			<td style="width: 5%;"><b><?php echo $model->getAttributeLabel('phase') ?>:</b></td>
			<td style="width: 5%;"><?php echo $model->phase ?></td>
		</tr>
		<tr>
			<td style="width: 17.5%;"><b><?php echo $model->getAttributeLabel('personal_week') ?>:</b></td>
			<td style="width: 17.5%;"><?php echo $model->personal_week ?></td>
			<td style="width: 17.5%;"><b><?php echo $model->getAttributeLabel('own_week') ?>:</b></td>
			<td style="width: 17.5%;"><?php echo $model->own_week ?></td>
			<td style="width: 5%;"><b><?php echo $model->getAttributeLabel('goal') ?>:</b></td>
			<td style="width: 25%;" colspan="5"><?php echo $model->goal ?></td>
		</tr>
	</table>
	<br/>
	<?php $values = $model->getValues();?>
	<table class="trainingplan-values" style="width:100%" cellspacing="0" border="1" cellpadding="1">
		<tr>
			<th style="width: 5%">&nbsp;</th>
			<th style="width: 8%">&Uuml;bungen</th>
			<th style="width: 8%">Ger&auml;t</th>
			<th style="width: 8%">Position</th>
			<th style="width: 8%">Gewicht /<br/>Inten.</th>
			<?php for ($i = 0; $i < 8; $i++): ?>
			<th style="width: 8%"><?php echo isset($values['dates'][$i]) ? $values['dates'][$i] : '' ?></th>
			<?php endfor; ?>
		</tr>
		<?php foreach ($values['sonsomo'] as $key => $row): ?>
			<tr>
			<?php if ($key == 0):?>
			<td style="width: 5%" rowspan="<?php echo count($values['sonsomo']) ?>">Son<br/>somo.</td>
			<?php endif; ?>
			<td style="width: 8%"><?php echo $row['exercise']?>&nbsp;</td>
			<td style="width: 8%"><?php echo $row['device']?>&nbsp;</td>
			<td style="width: 8%"><?php echo $row['position']?>&nbsp;</td>
			<td style="width: 8%"><?php echo $row['weight']?>&nbsp;</td>
			<?php for ($j = 0; $j < 8; $j++): ?>
			<td style="width: 8%"><?php echo isset($row['dates'][$j]) ? $row['dates'][$j] : '' ?>&nbsp;</td>
			<?php endfor; ?>
			</tr>
		<?php endforeach; ?>
		<?php foreach ($values['main'] as $key => $row):?>
			<tr>
			<?php if ($key == 0):?>
			<td style="width: 5%" rowspan="<?php echo count($values['main']) ?>">Haup<br/>teil</td>
			<?php endif; ?>
			<td style="width: 8%"><?php echo $row['exercise']?>&nbsp;</td>
			<td style="width: 8%"><?php echo $row['device']?>&nbsp;</td>
			<td style="width: 8%"><?php echo $row['position']?>&nbsp;</td>
			<td style="width: 8%"><?php echo $row['weight']?>&nbsp;</td>
			<?php for ($j = 0; $j < 8; $j++): ?>
			<td style="width: 8%"><?php echo isset($row['dates'][$j]) ? $row['dates'][$j] : '' ?>&nbsp;</td>
			<?php endfor; ?>
			</tr>
		<?php endforeach; ?>
		<?php foreach ($values['core'] as $key => $row):?>
			<tr>
			<?php if ($key == 0):?>
			<td style="width: 5%" rowspan="<?php echo count($values['core']) ?>">Core<br/>training</td>
			<?php endif; ?>
			<td style="width: 8%"><?php echo $row['exercise']?>&nbsp;</td>
			<td style="width: 8%"><?php echo $row['device']?>&nbsp;</td>
			<td style="width: 8%"><?php echo $row['position']?>&nbsp;</td>
			<td style="width: 8%"><?php echo $row['weight']?>&nbsp;</td>
			<?php for ($j = 0; $j < 8; $j++): ?>
			<td style="width: 8%"><?php echo isset($row['dates'][$j]) ? $row['dates'][$j] : '' ?>&nbsp;</td>
			<?php endfor; ?>
			</tr>
		<?php endforeach; ?>	
	</table>
	<br/>
	<div class="row">
		<b><?php echo $model->getAttributeLabel('type') ?>:</b> <?php echo $model->getType() ?>
	</div>
